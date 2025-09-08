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
    defaults [
      :read,
      :destroy,
      create: [:user_id],
      update: [:user_id, :posts_without_images, :posts_with_images, :reposts, :likes, :max_age]
    ]
  end

  policies do
    policy actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type([:create]) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id
    timestamps()

    attribute :posts_without_images, :boolean, default: false, public?: true
    attribute :posts_with_images, :boolean, default: false, public?: true
    attribute :reposts, :boolean, default: false, public?: true
    attribute :likes, :boolean, default: false, public?: true

    attribute :max_age, :integer, constraints: [min: 1, max: 365]
  end

  relationships do
    belongs_to :user, SkeetDeleter.Accounts.User
  end
end
