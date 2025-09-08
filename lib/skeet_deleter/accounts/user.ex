defmodule SkeetDeleter.Accounts.User do
  use Ash.Resource,
    otp_app: :skeet_deleter,
    domain: SkeetDeleter.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshCloak]

  postgres do
    table "users"
    repo SkeetDeleter.Repo
  end

  cloak do
    vault(SkeetDeleter.Vault)
    attributes([:access_token, :refresh_token])
  end

  actions do
    defaults [:read]

    create :create do
      accept [:did, :handle, :access_token, :refresh_token, :token_expiration]
    end

    update :update do
      primary? true
      accept [:handle, :access_token, :refresh_token, :token_expiration]
    end

    read :get_by_did do
      argument :did, :string do
        allow_nil? false
      end

      get? true
      filter expr(did == ^arg(:did))
    end
  end

  policies do
    policy actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if expr(id == ^actor(:id))
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :did, :string do
      allow_nil? false
    end

    attribute :role, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:subscriber, :super]
      default :subscriber
    end

    attribute :access_token, :string
    attribute :refresh_token, :string
    attribute :token_expiration, :utc_datetime

    attribute :handle, :string do
      public? true
    end
  end

  relationships do
    has_many :actions, SkeetDeleter.Actions.Action
  end

  identities do
    identity :unique_did, [:did]
  end
end
