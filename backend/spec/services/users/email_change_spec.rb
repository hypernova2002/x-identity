require "rails_helper"

RSpec.describe Users::EmailChange do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, email: "olive@acme.test") }
  let(:change) { described_class.new(account: account) }

  def requested_token
    change.deliver(user: user, new_email: "olive@new.test")
    OneTimeToken.issue!(subject: user, purpose: :email_change, data: { "new_email" => "olive@new.test" }).last
  end

  it "refuses an address that isn't one, or is the user's own" do
    [ "not-an-email", "#{'a' * 250}@acme.test" ].each do |address|
      expect { change.request(user: user, new_email: address, current_password: "correct horse battery staple") }
        .to raise_error(ApiError) { |error| expect(error.details.first).to include(field: "new_email", code: "invalid") }
    end
    expect { change.request(user: user, new_email: "olive@acme.test", current_password: "correct horse battery staple") }
      .to raise_error(ApiError) { |error| expect(error.details.first).to include(code: "same_as_current_email") }
  end

  it "doesn't confirm for a user who was disabled since" do
    token = requested_token
    user.update!(status: "disabled")

    expect { change.confirm(token: token) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_token) }
  end

  it "refuses when a concurrent confirmation used the link first" do
    token = requested_token
    allow(OneTimeToken).to receive(:find_usable).and_wrap_original do |original, *args, **options|
      original.call(*args, **options).tap { |record| allow(record).to receive(:consume!).and_return(false) if record }
    end

    expect { change.confirm(token: token) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:invalid_token) }
    expect(user.reload.email).to eq("olive@acme.test")
  end

  it "says the address is taken when the unique index catches a concurrent change" do
    token = requested_token
    allow_any_instance_of(User).to receive(:update!).and_raise(ActiveRecord::RecordNotUnique)

    expect { change.confirm(token: token) }.to raise_error(ApiError) { |error| expect(error.code).to eq(:email_taken) }
  end
end
