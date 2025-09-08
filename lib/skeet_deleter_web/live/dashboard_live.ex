defmodule SkeetDeleterWeb.DashboardLive do
  alias SkeetDeleter.Actions
  use SkeetDeleterWeb, :live_view

  def mount(_params, session, socket) do
    %{"current_user" => user} = session
    user = Ash.load!(user, [:actions], actor: user)

    action =
      case user.actions do
        [a | _] -> a
        [] -> Actions.create_action!(%{user_id: user.id})
      end

    action_form = Actions.form_to_update_action(action, actor: user) |> to_form()

    {:ok,
     socket
     |> assign(:current_user, user)
     |> assign(:action, action)
     |> assign(:action_form, action_form)}
  end

  def handle_event("update_action", %{"form" => params}, socket) do
    %{assigns: %{action_form: form, current_user: current_user}} = socket
    dbg(params)

    truthy = ["on", 1, "1", true, "true"]

    params =
      params
      |> Map.update("likes", false, &(&1 in truthy))
      |> Map.update("reposts", false, &(&1 in truthy))
      |> Map.update("posts_with_images", false, &(&1 in truthy))
      |> Map.update("posts_without_images", false, &(&1 in truthy))

    case AshPhoenix.Form.submit(form, params: params) do
      {:ok, action} ->
        action_form =
          Actions.form_to_update_action(action, actor: current_user) |> to_form()

        {
          :noreply,
          socket
          |> assign(:action, action)
          |> assign(:action_form, action_form)
          |> put_flash(:success, "Updates saved!")
        }

      {:error, action_form} ->
        socket =
          socket
          |> put_flash(:error, "Something went wrong")
          |> assign(:action_form, action_form)

        {:noreply, socket}
    end
  end
end
