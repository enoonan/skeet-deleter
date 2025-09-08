defmodule SkeetDeleter.Records do
  use Ash.Domain
  alias SkeetDeleter.Records.Post

  resources do
    resource Post do
      define :posts_from_author, args: [:did], action: :from_author
    end
  end
end
