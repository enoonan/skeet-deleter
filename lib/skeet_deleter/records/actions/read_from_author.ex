defmodule SkeetDeleter.Records.Actions.ReadFromAuthor do
  @moduledoc """
    Queries the user's Bluesky feed
    https://docs.bsky.app/docs/api/app-bsky-feed-get-author-feed
    https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed?actor=did:plc:fgu6fltgbrfq3feill27dtyj&cursor=2025-09-02T18:34:22.911Z&limit=12

    What I have learned:
     - get the author's feed which includes posts, which can be filtered, but not likes. Likes are a separate API call
        - https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed?actor={did}&cursor={cursor}&limit=100
     - "page" through the posts by using the "cursor" param, which is a timestamp like so: "2025-09-02T18:34:22.911Z
     - cursor value can be found on the body["cursor"] of the response
     - if bod["cursor"] is not present, it means there are no more posts to retrieve. NICE
     - this request is not authenticated
  """

  use Ash.Resource.ManualRead

  alias Ash.Query
  alias SkeetDeleter.Records.Post

  @impl true
  def read(query, _, _opts, _ctx) do
    with {:ok, did} <- query |> init_did(),
         {:ok, cursor} <- query |> init_cursor() do
      dbg({did, cursor})
      {:ok, get_posts(did, cursor)}
    end
  end

  defp get_posts(did, cursor, curr_posts \\ []) do
    case url(did, cursor) |> Req.get() do
      {:ok, %{status: 200, body: body}} ->
        curr_posts =
          body["feed"]
          |> Enum.map(&to_post/1)
          |> Enum.reverse()
          |> then(&(&1 ++ curr_posts))

        # BROADCAST CURR_POST LENGTH
        IO.inspect("Got: #{curr_posts |> length} posts")

        case body["cursor"] do
          nil -> curr_posts
          _ -> get_posts(did, body["cursor"], curr_posts)
        end

      err ->
        dbg(err)
        raise "Error fetching posts"
    end
  end

  defp to_post(%{"post" => %{"cid" => cid, "record" => record}} = _post) do
    %Post{
      cid: cid,
      text: record["text"]
    }
  end

  defp init_did(query) do
    case query |> Query.fetch_argument(:did) do
      {:ok, val} -> {:ok, val |> to_did}
      err -> err
    end
  end

  defp to_did(%{type: :user, value: %{did: did}}), do: did
  defp to_did(%{type: :did, value: did}), do: did
  defp to_did(_), do: :invalid_argument

  defp init_cursor(query) do
    with {:ok, cursor_unit} <- query |> Query.fetch_argument(:cursor_unit),
         {:ok, cursor_qty} <- query |> Query.fetch_argument(:cursor_qty) do
      shift_duration = Keyword.new([{cursor_unit, cursor_qty * -1}])

      {:ok,
       DateTime.utc_now()
       |> DateTime.shift(shift_duration)
       |> DateTime.to_iso8601(:extended)}
    end
  end

  defp url(did, cursor) do
    "https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed?actor=#{did}&cursor=#{cursor}&limit=100"
  end
end
