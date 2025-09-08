defmodule SkeetDeleter.Records.Post do
  use Ash.Resource,
    domain: SkeetDeleter.Records,
    authorizers: [Ash.Policy.Authorizer]

  alias SkeetDeleter.Records.Actions.ReadFromAuthor
  alias SkeetDeleter.Accounts.User

  resource do
    require_primary_key? false
  end

  actions do
    read :from_author do
      argument :did, :union do
        constraints types: [
                      did: [type: :string],
                      user: [type: :struct, constraints: [instance_of: User]]
                    ]

        allow_nil? false
      end

      argument :cursor_unit, :atom do
        constraints one_of: [:day, :week, :month, :year]
        default :month
      end

      argument :cursor_qty, :integer do
        default 1
        constraints min: 0, max: 1000
      end

      argument :filter, :atom do
        constraints one_of: [
                      :posts_with_replies,
                      :posts_no_replies,
                      :posts_with_media,
                      :posts_and_author_threads,
                      :posts_with_video
                    ]

        default :posts_with_replies
      end

      manual ReadFromAuthor
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    policy actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type([:read]) do
      authorize_if always()
    end
  end

  attributes do
    attribute :cid, :string
    attribute :text, :string
  end
end
