defmodule SkeetDeleterWeb.DashboardLive do
  alias SkeetDeleter.Accounts
  use SkeetDeleterWeb, :live_view

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    dbg(user)

    user_form = Accounts.form_to_update_user(user, actor: user) |> to_form()

    app_key_form = Accounts.form_to_update_user_app_key(user, actor: user) |> to_form()

    {:ok,
     socket
     |> assign(:user_form, user_form)
     |> assign(:app_key_form, app_key_form)}
  end

  def handle_event("update_user", params, socket) do
    %{assigns: %{user_form: form, current_user: current_user}} = socket

    case AshPhoenix.Form.submit(form, params: params) |> dbg do
      {:ok, user} ->
        user_form =
          Accounts.form_to_update_user(user, actor: current_user) |> to_form()

        {
          :noreply,
          socket
          |> assign(:current_user, user)
          |> assign(:user_form, user_form)
          |> put_flash(:success, "Updates saved!")
          |> dbg
        }

      {:error, user_form} ->
        socket =
          socket
          |> put_flash(:error, "Something went wrong")
          |> assign(:user_form, user_form)
          |> then(fn s -> dbg(s.assigns) end)

        {:noreply, socket}
    end
  end

  def handle_event("update_app_key", params, socket) do
    %{assigns: %{app_key_form: form, current_user: current_user}} = socket

    case AshPhoenix.Form.submit(form, params: params) |> dbg do
      {:ok, user} ->
        app_key_form =
          Accounts.form_to_update_user_app_key(user, actor: current_user) |> to_form()

        {
          :noreply,
          socket
          |> assign(:current_user, user)
          |> assign(:app_key_form, app_key_form)
          |> put_flash(:success, "Updates saved!")
        }

      {:error, app_key_form} ->
        socket =
          socket
          |> put_flash(:error, "Something went wrong")
          |> assign(:app_key_form, app_key_form)

        {:noreply, socket}
    end
  end
end
