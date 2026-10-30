module Passkeys
  class RenameRequest < ApplicationRequestModel
    attribute :name, Fields::Name
  end
end
