module Mfa
  Enrollment = Data.define(:otp_type, :digits, :step_seconds, :secret, :provisioning_uri, :qr_code_svg)
end
