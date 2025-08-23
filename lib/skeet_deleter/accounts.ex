defmodule SkeetDeleter.Accounts do
  use Ash.Domain, otp_app: :skeet_deleter, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource SkeetDeleter.Accounts.Token
    resource SkeetDeleter.Accounts.User
  end
end
