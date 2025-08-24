defmodule SkeetDeleter.Accounts do
  use Ash.Domain,
    otp_app: :skeet_deleter,
    extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource SkeetDeleter.Accounts.Token

    resource SkeetDeleter.Accounts.User do
      define :update_user, action: :update
      define :update_user_app_key, action: :update_app_key
    end
  end
end
