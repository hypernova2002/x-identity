module Passkeys
  # Field types shared by the passkey requests. A credential is the browser's PublicKeyCredential as
  # JSON (its toJSON()), with binary values base64url-encoded, so n characters hold about 3n/4 bytes.
  module Fields
    T = RequestTypes::T

    Name = T::String.constrained(min_size: 1, max_size: 60).meta(description: "The passkey's name, shown in the user's list of passkeys.")

    CredentialId = T::String.constrained(min_size: 1, max_size: 1364).meta(description: "The credential ID, base64url-encoded.")
    RawId = CredentialId.meta(description: "The credential ID, base64url-encoded (the same as id).")
    CredentialType = T::String.enum("public-key").meta(description: "Always public-key.")
    AuthenticatorAttachment = T::String.enum("platform", "cross-platform").optional
      .meta(description: "Where the passkey is: platform (this device) or cross-platform (a security key or phone).")
    ClientExtensionResults = T::Hash.constrained(max_size: 16).optional.meta(description: "The results of WebAuthn extensions, keyed by extension.")

    ClientDataJson = T::String.constrained(min_size: 1, max_size: 8192).meta(description: "The client data the browser passed to the authenticator.")
    AuthenticatorData = T::String.constrained(min_size: 1, max_size: 8192).meta(description: "The authenticator data.")
    Signature = T::String.constrained(min_size: 1, max_size: 2048).meta(description: "The authenticator's signature.")
    UserHandle = T::String.constrained(min_size: 1, max_size: 86).optional.meta(description: "The user handle the passkey was created with.")
    AttestationObject = T::String.constrained(min_size: 1, max_size: 65_536).meta(description: "The attestation object.")
    Transports = T::Array.of(T::String.constrained(min_size: 1, max_size: 32)).constrained(max_size: 10)
      .meta(description: "How the authenticator can be reached, e.g. internal, hybrid or usb.")
    PublicKey = T::String.constrained(min_size: 1, max_size: 8192).optional.meta(description: "The new credential's public key (SubjectPublicKeyInfo).")
    PublicKeyAlgorithm = T::Integer.meta(description: "The public key's COSE algorithm, e.g. -7 for ES256.")
  end
end
