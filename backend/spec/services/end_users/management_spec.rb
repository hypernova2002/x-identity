require "rails_helper"

RSpec.describe EndUsers::Management do
  include ActiveJob::TestHelper

  let(:project) { create(:project) }
  let(:admin) { create(:user, :admin, account: project.account) }
  let(:management) { described_class.new(actor: admin, project: project) }

  before { project.end_user_attribute_definitions.create!(key: "seats", label: "Seats", data_type: "number") }

  def error(&block)
    expect(&block).to raise_error(ApiError) { |raised| return raised }
  end

  describe "creating" do
    it "can skip the invitation" do
      expect { management.create(email: "new@shop.test", send_invitation: false) }.not_to have_enqueued_job(EndUserEmailJob)
      expect(AuditEvent.last.metadata).to eq("invited" => false)
    end

    it "refuses invalid attributes and fields, saving nothing" do
      expect(error { management.create(email: "new@shop.test", custom_attributes: { "seats" => "many" }) }.details.first).to include(field: "custom_attributes.seats")
      expect(error { management.create(email: "new@shop.test", name: "n" * 101) }.details.first).to include(field: "name", code: "too_long")
      expect(project.end_users.reload).to be_empty
    end

    it "says the email is taken when a concurrent request saved it first, as the unique index reports" do
      allow_any_instance_of(EndUser).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      expect(error { management.create(email: "new@shop.test") }).to have_attributes(code: :email_taken, reason: :end_user_email_taken)
    end
  end

  describe "updating" do
    let(:end_user) { create(:end_user, project: project, custom_attributes: { "seats" => 3 }) }

    it "refuses invalid attributes and fields, changing nothing" do
      expect(error { management.update(end_user, custom_attributes: { "seats" => "many" }) }.code).to eq(:validation_failed)
      expect(error { management.update(end_user, name: "n" * 101) }.code).to eq(:validation_failed)
      expect(end_user.reload).to have_attributes(custom_attributes: { "seats" => 3 }, name: "Casey Customer")
    end

    it "re-enables a disabled user, recording only what changed" do
      end_user.update!(status: "disabled")

      management.update(end_user, status: "active")

      expect(end_user.reload).to be_active
      expect(AuditEvent.pluck(:action)).to eq([ "end_user.enabled" ])
    end

    it "records the fields changed, and nothing for a status it already has" do
      management.update(end_user, name: "Casey", status: "active")

      expect(AuditEvent.pluck(:action, :metadata)).to eq([ [ "end_user.updated", { "fields" => [ "name" ] } ] ])
    end
  end
end
