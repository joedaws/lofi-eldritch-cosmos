defmodule LofiWeb.UserSettingsController do
  use LofiWeb, :controller

  alias Lofi.Accounts
  alias LofiWeb.UserAuth

  import LofiWeb.UserAuth, only: [require_sudo_mode: 2]

  plug :require_sudo_mode
  plug :assign_email_and_password_changesets
  plug :assign_agent_tokens

  def edit(conn, _params) do
    render(conn, :edit)
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"/users/settings")

      changeset ->
        render(conn, :edit, email_changeset: %{changeset | action: :insert})
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.update_user_password(user, user_params) do
      {:ok, {user, _}} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, :edit, password_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_scope.user, token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/users/settings")

      {:error, _} ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  # A token for the person's learning agent; shown once, never again
  def create_agent_token(conn, %{"agent_token" => %{"name" => name}}) do
    user = conn.assigns.current_scope.user

    case Accounts.create_agent_token(user, name) do
      {:ok, plain, _token} ->
        conn
        |> assign(:agent_tokens, Accounts.list_agent_tokens(user))
        |> render(:edit, new_agent_token: plain)

      {:error, :too_many_tokens} ->
        conn
        |> put_flash(:error, "You already have 10 agent tokens. Revoke one first.")
        |> redirect(to: ~p"/users/settings")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Give the token a name (at most 40 characters).")
        |> redirect(to: ~p"/users/settings")
    end
  end

  def revoke_agent_token(conn, %{"id" => id}) do
    user = conn.assigns.current_scope.user

    case Accounts.revoke_agent_token(user, id) do
      {:ok, token} -> put_flash(conn, :info, "Revoked the token \"#{token.name}\".")
      _ -> put_flash(conn, :error, "No such token.")
    end
    |> redirect(to: ~p"/users/settings")
  end

  defp assign_agent_tokens(conn, _opts) do
    conn
    |> assign(:agent_tokens, Accounts.list_agent_tokens(conn.assigns.current_scope.user))
    |> assign(:new_agent_token, nil)
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    user = conn.assigns.current_scope.user

    conn
    |> assign(:email_changeset, Accounts.change_user_email(user))
    |> assign(:password_changeset, Accounts.change_user_password(user))
  end
end
