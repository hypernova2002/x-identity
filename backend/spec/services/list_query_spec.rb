require "rails_helper"

RSpec.describe ListQuery do
  let(:project) { create(:project) }
  let(:query) do
    described_class.new(
      search: "name_i_cont",
      filters: %i[default_for_new_users_eq],
      sorts: { "name" => :name, "member_count" => "(SELECT COUNT(*) FROM group_memberships WHERE group_memberships.group_id = groups.id)" },
      default_sort: "name"
    )
  end

  def names(params)
    query.call(project.groups, ActionController::Parameters.new(params)).map(&:name)
  end

  before do
    staff = create(:group, project: project, name: "Staff")
    2.times { staff.group_memberships.create!(end_user: create(:end_user, project: project, in_all_end_users_group: false)) }
    create(:group, project: project, name: "Support", default_for_new_users: true)
    create(:group, project: project, name: "Admins")
  end

  it "sorts by the default when no sort is given" do
    expect(names({})).to eq(%w[Admins Staff Support])
  end

  it "sorts descending with a leading minus, including by derived values" do
    expect(names(sort: "-name")).to eq(%w[Support Staff Admins])
    expect(names(sort: "-member_count").first).to eq("Staff")
  end

  it "orders ties by id so pages don't overlap" do
    sql = query.call(project.groups, ActionController::Parameters.new(sort: "member_count")).to_sql

    expect(sql).to end_with(%("groups"."id" ASC))
  end

  it "maps q[search] to the listing's search predicate and combines filters" do
    expect(names(q: { search: "sta" })).to eq(%w[Staff])
    expect(names(q: { search: "s", default_for_new_users_eq: "false" })).to eq(%w[Admins Staff])
  end

  it "ignores filters the listing doesn't allow" do
    expect(names(q: { project_id_eq: 0 })).to eq(%w[Admins Staff Support])
  end

  it "refuses an unknown sort" do
    expect { names(sort: "description") }.to raise_error(ApiError) { |error| expect(error.details.sole[:field]).to eq("sort") }
  end

  it "refuses a default sort it doesn't offer, when the listing is defined" do
    expect { described_class.new(sorts: { "name" => :name }, default_sort: "-created_at") }.to raise_error(ArgumentError, /created_at/)
  end

  it "can't be changed once defined" do
    expect(query).to be_frozen
  end
end
