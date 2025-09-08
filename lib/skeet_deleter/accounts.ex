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
      define :read_users, action: :read
      define :get_user_by_did, action: :read, get_by: [:did]
      define :create_user, action: :create
      define :update_user, action: :update
    end
  end
end
