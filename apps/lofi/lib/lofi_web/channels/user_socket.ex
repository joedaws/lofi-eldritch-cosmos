defmodule LofiWeb.UserSocket do
  @moduledoc """
  The page's live connection. Anyone may connect and watch; a signed-in
  person is recognised from their browser session, so the world they are
  pushed is tailored to them (see `LofiWeb.WorldView`).
  """
  use Phoenix.Socket

  channel "world", LofiWeb.WorldChannel

  @impl true
  def connect(_params, socket, connect_info) do
    {:ok, assign(socket, :user_id, user_id(connect_info))}
  end

  @impl true
  def id(_socket), do: nil

  defp user_id(%{session: %{"user_token" => token}}) when is_binary(token) do
    case Lofi.Accounts.get_user_by_session_token(token) do
      {user, _inserted_at} -> user.id
      _ -> nil
    end
  end

  defp user_id(_), do: nil
end
