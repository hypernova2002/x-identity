require "rails_helper"

RSpec.describe EndUsers::CodeThrottle do
  let(:project) do
    create(:project).tap do |project|
      project.auth_configuration!.update!(email_code_max_attempts: 10, email_code_max_failures_per_email: 4, email_code_max_failures_per_code: 3)
    end
  end
  let(:redemption) { EndUsers::CodeRedemption.new(project: project, ip: "203.0.113.7") }

  def redeem(email, code)
    redemption.find!(purpose: :password_reset, email: email, code: code)
  rescue ApiError => error
    error.code
  end

  def issue_code(end_user)
    OneTimeToken.issue_with_code!(subject: end_user, purpose: :password_reset).code
  end

  describe "per email address" do
    let(:end_user) { create(:end_user, project: project) }

    it "keeps counting when new codes are requested" do
      issue_code(end_user)
      4.times { |n| redeem(end_user.email, format("1000%02d", n)) }

      expect(redeem(end_user.email, issue_code(end_user))).to eq(:invalid_code)
    end

    it "lets the right code through below the limit" do
      redeem(end_user.email, "100000")

      expect(redeem(end_user.email, issue_code(end_user))).to be_a(OneTimeToken)
    end
  end

  describe "per code value" do
    it "refuses a code value tried on too many addresses, even where it is right" do
      3.times { |n| redeem("nobody#{n}@shop.test", "123456") }
      victim = create(:end_user, project: project)
      allow(SecureRandom).to receive(:random_number).and_call_original
      allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(123_456)
      OneTimeToken.issue_with_code!(subject: victim, purpose: :password_reset)

      expect(redeem(victim.email, "123456")).to eq(:invalid_code)
    end

    it "counts guesses against addresses that don't exist" do
      3.times { |n| redeem("nobody#{n}@shop.test", "123456") }

      expect(described_class.new(project: project).code_blocked?("123456")).to be(true)
    end

    it "isn't used for new codes while it's blocked" do
      3.times { |n| redeem("nobody#{n}@shop.test", "123456") }
      allow(SecureRandom).to receive(:random_number).and_call_original
      allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(123_456, 654_321)
      ActionMailer::Base.deliveries.clear

      EndUsers::Emails.new(project: project).send_password_reset(create(:end_user, project: project, email: "casey@shop.test"))

      expect(last_code_sent_to("casey@shop.test")).to eq("654321")
    end

    it "records when the limit is reached" do
      3.times { |n| redeem("nobody#{n}@shop.test", "123456") }

      expect(AuditEvent.where(project: project, action: "end_user.code_limit_reached").pluck(:metadata).pluck("limit")).to include("code")
    end
  end

  describe "per IP address" do
    it "refuses all code checks from an IP after too many failures" do
      described_class::MAX_FAILURES_PER_IP.times { |n| redeem("nobody#{n}@shop.test", format("%06d", n)) }

      expect(redeem("someone@shop.test", "999999")).to eq(:too_many_attempts)
    end

    it "doesn't limit callers without an IP" do
      throttle = described_class.new(project: project)

      expect(throttle.attempt(email: "x@shop.test", code: "000001") { true }).to be(true)
    end
  end
end
