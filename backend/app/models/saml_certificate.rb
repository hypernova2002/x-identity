# The certificate a project signs SAML messages with. RSA, because many SAML apps can't verify
# other keys. Rotation: add a `next` certificate (published in metadata, so apps can pick it up),
# make it `active`, and remove the retired one once apps have switched.
class SamlCertificate < ApplicationRecord
  include HasUid

  self.uid_prefix = "scert"

  KEY_BITS = 2048
  LIFETIME = 10.years

  belongs_to :project

  enum :status, { next: "next", active: "active", retired: "retired" }, prefix: true, validate: true

  encrypts :private_key

  scope :published, -> { where(status: %w[next active retired]) }

  # @param project [Project]
  # @param status [String]
  # @return [SamlCertificate]
  def self.generate!(project:, status:)
    key = OpenSSL::PKey::RSA.generate(KEY_BITS)
    now = Time.current
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = OpenSSL::BN.rand(64)
    certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse("/CN=x-identity #{project.uid}")
    certificate.public_key = key.public_key
    certificate.not_before = now - 1.minute
    certificate.not_after = now + LIFETIME
    certificate.sign(key, OpenSSL::Digest.new("SHA256"))

    create!(
      project: project, status: status, private_key: key.to_pem, certificate: certificate.to_pem,
      activated_at: (now if status.to_s == "active"), expires_at: certificate.not_after
    )
  end

  # @param project [Project]
  # @return [SamlCertificate] the project's active certificate, created on first use
  def self.active_for!(project)
    project.saml_certificates.status_active.order(activated_at: :desc).first || generate!(project: project, status: "active")
  end

  # @return [OpenSSL::PKey::RSA]
  def signing_key
    OpenSSL::PKey::RSA.new(private_key)
  end

  # @return [OpenSSL::X509::Certificate]
  def x509
    OpenSSL::X509::Certificate.new(certificate)
  end

  # @return [String] base64 DER, as it appears in metadata
  def base64_der
    Base64.strict_encode64(x509.to_der)
  end
end
