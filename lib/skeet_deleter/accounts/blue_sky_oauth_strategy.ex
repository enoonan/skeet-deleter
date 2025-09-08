defmodule SkeetDeleter.Accounts.BlueSkyOauthStrategy do
  # use AshAuthentication.Strategy.Custom

  # @entity %Spark.Dsl.Entity{
  #   name: :bluesky,
  #   describe: "Log in with Blue Sky account",
  #   examples: [
  #     """
  #     bluesky do
  #       name_field :handle
  #     end
  #     """
  #   ],
  #   target: __MODULE__,
  #   args: [{:optional, :name, :marty}],
  #   schema: [
  #     name: [
  #       type: :atom,
  #       doc: """
  #       The strategy name.
  #       """,
  #       required: true
  #     ],
  #     case_sensitive?: [
  #       type: :boolean,
  #       doc: """
  #       Ignore letter case when comparing?
  #       """,
  #       required: false,
  #       default: false
  #     ],
  #     name_field: [
  #       type: :atom,
  #       doc: """
  #       The field to check for the users' name.
  #       """,
  #       required: true
  #     ]
  #   ]
  # }

  # use AshAuthentication.Strategy.Custom, entity: @entity
end
