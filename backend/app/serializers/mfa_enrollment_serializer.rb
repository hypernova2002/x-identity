class MfaEnrollmentSerializer
  include Alba::Resource

  attributes :secret, :provisioning_uri, :qr_code_svg
end
