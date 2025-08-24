defmodule SkeetDeleterWeb.PageController do
  use SkeetDeleterWeb, :controller

  def home(conn, _params) do
    case Map.get(conn.assigns, :current_user) do
      nil -> conn |> redirect(to: ~p"/sign-in")
      _ -> render(conn, :home)
    end
  end
end
