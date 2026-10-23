class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # List endpoints can only search associations a model allows explicitly.
  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
