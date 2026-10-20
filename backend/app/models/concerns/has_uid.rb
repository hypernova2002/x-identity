# Gives a model a public, prefixed, non-sequential identifier (e.g. `acct_3xK9...`).
# Including models must have a unique, indexed `uid` string column and set `self.uid_prefix`.
module HasUid
  extend ActiveSupport::Concern

  RANDOM_LENGTH = 24

  included do
    class_attribute :uid_prefix, instance_writer: false

    before_validation :generate_uid, on: :create

    validates :uid, presence: true, uniqueness: true
  end

  class_methods do
    # @param uid [String]
    # @return [ActiveRecord::Base]
    # @raise [ActiveRecord::RecordNotFound]
    def find_by_uid!(uid)
      find_by!(uid: uid)
    end
  end

  def to_param
    uid
  end

  private

  def generate_uid
    raise ArgumentError, "#{self.class.name} must set uid_prefix" if uid_prefix.blank?

    self.uid ||= "#{uid_prefix}_#{SecureRandom.base58(RANDOM_LENGTH)}"
  end
end
