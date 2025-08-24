defmodule SkeetDeleter.Actions.Action do
  use Ash.Resource,
    otp_app: :skeet_deleter,
    domain: SkeetDeleter.Actions,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "actions"
    repo SkeetDeleter.Repo
  end

  actions do
    defaults [:read, :destroy, create: [], update: []]
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :user, SkeetDeleter.Accounts.User
  end
end
