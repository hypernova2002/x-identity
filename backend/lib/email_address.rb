# The canonical form of an email address, used to store, look up and compare addresses:
# trimmed, Unicode NFC-normalised (so visually identical addresses compare equal) and lowercased.
#
# Provider-specific rules, such as ignoring dots or +tags in Gmail addresses, are deliberately not
# applied: elsewhere those can be different mailboxes, and merging them would merge identities.
module EmailAddress
  # @param email [String, nil]
  # @return [String]
  def self.normalize(email)
    email.to_s.strip.unicode_normalize(:nfc).downcase
  end
end
