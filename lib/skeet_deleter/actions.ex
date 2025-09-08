defmodule SkeetDeleter.Actions do
  use Ash.Domain,
    otp_app: :skeet_deleter,
    extensions: [AshPhoenix]

  resources do
    resource SkeetDeleter.Actions.Action do
      define :create_action, action: :create
      define :update_action, action: :update
    end
  end
end
