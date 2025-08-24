defmodule SkeetDeleter.Actions do
  use Ash.Domain,
    otp_app: :skeet_deleter

  resources do
    resource SkeetDeleter.Actions.Action
  end
end
