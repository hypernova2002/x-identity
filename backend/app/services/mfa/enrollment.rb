module Mfa
  Enrollment = Data.define(:secret, :provisioning_uri, :qr_code_svg)
end
