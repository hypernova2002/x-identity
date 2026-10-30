require "rails_helper"

RSpec.describe AuthConfigurations::UpdateRequest do
  let(:valid_body) { {} }

  it_behaves_like "an optional field", :mfa_requirement
  it_behaves_like "an enum field", :mfa_requirement, values: AuthConfiguration.mfa_requirements.keys

  it_behaves_like "an optional field", :passkeys
  it_behaves_like "an enum field", :passkeys, values: AuthConfiguration.passkeys.keys

  it_behaves_like "an optional field", :signing_algorithm
  it_behaves_like "an enum field", :signing_algorithm, values: SigningKey::ALGORITHMS

  it_behaves_like "an optional field", :otp_method
  it_behaves_like "an enum field", :otp_method, values: AuthConfiguration::OTP_METHODS

  %i[require_email_verification notify_new_devices passwordless_after_passkey password_require_uppercase password_require_lowercase
     password_require_number password_require_symbol].each do |field|
    it_behaves_like "an optional field", field
    it_behaves_like "a boolean field", field
  end

  {
    password_min_length: 8..AuthConfiguration::PASSWORD_MAX_LENGTH,
    lockout_threshold: 3..100,
    mfa_max_failed_attempts: 3..20,
    email_code_max_attempts: 3..10,
    email_code_max_failures_per_email: 3..100,
    email_code_max_failures_per_code: 2..100,
    otp_digits: AuthConfiguration::OTP_DIGITS,
    otp_step_seconds: AuthConfiguration::OTP_STEP_SECONDS,
    otp_drift_steps: 0..2,
    otp_hotp_look_ahead: 1..20
  }.each do |field, range|
    it_behaves_like "an optional field", field
    it_behaves_like "an integer field", field, min: range.min, max: range.max
  end

  AuthConfiguration::DURATION_RANGES.each do |field, range|
    it_behaves_like "an optional field", field
    it_behaves_like "an integer field", field, min: range.min, max: range.max, nullable: AuthConfiguration::OPTIONAL_DURATIONS.include?(field)
  end

  it_behaves_like "an optional field", :token_requests_per_minute
  it_behaves_like "a token requests per minute field", :token_requests_per_minute
end
