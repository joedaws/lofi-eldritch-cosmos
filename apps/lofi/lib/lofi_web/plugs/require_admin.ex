defmodule LofiWeb.Plugs.RequireAdmin do
  @moduledoc "Routes that run the cosmos itself are for the admin only."
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_scope] do
      %{user: %{is_admin: true}} ->
        conn

      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{"error" => "only the keeper of the cosmos may do that"})
        |> halt()
    end
  end
end
