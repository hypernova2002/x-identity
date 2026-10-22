class SamlCertificateSerializer
  include Alba::Resource

  attributes :uid, :status, :certificate, :activated_at, :expires_at, :created_at
  attribute(:fingerprint_sha256) { |certificate| OpenSSL::Digest::SHA256.hexdigest(certificate.x509.to_der).scan(/../).join(":").upcase }
end
