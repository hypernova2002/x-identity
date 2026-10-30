require "rails_helper"

RSpec.describe "End user updates that race another request" do
  let(:project) { create(:project) }
  let(:end_user) { create(:end_user, project: project) }
  let(:admin) { create(:user, :admin, account: project.account) }

  before do
    create(:end_user_attribute_definition, project: project, key: "team", data_type: "string")
    create(:end_user_attribute_definition, project: project, key: "department", data_type: "string")
  end

  def changed_by_another_request(stale)
    EndUser.where(id: stale.id).update_all(custom_attributes: { "team" => "Blue" })
    stale
  end

  it "keeps the other request's attribute when an end user edits their profile" do
    EndUsers::Profile.new(end_user: changed_by_another_request(end_user)).update(custom_attributes: { department: "Sales" })

    expect(end_user.reload.custom_attributes).to eq({ "team" => "Blue", "department" => "Sales" })
  end

  it "keeps the other request's attribute when an admin edits the end user" do
    EndUsers::Management.new(actor: admin, project: project).update(changed_by_another_request(end_user), custom_attributes: { department: "Sales" })

    expect(end_user.reload.custom_attributes).to eq({ "team" => "Blue", "department" => "Sales" })
  end

  it "doesn't write back an attribute deleted after the end user was loaded" do
    end_user.update!(custom_attributes: { "team" => "Blue" })
    stale = EndUser.find(end_user.id)
    AttributeDefinitions::Management.new(actor: admin, project: project).destroy(project.end_user_attribute_definitions.find_by!(key: "team"))

    EndUsers::Profile.new(end_user: stale).update(custom_attributes: { department: "Sales" })

    expect(end_user.reload.custom_attributes).to eq({ "department" => "Sales" })
  end
end
