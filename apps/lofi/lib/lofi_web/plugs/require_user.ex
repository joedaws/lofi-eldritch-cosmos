defmodule LofiWeb.Plugs.RequireUser do
  @moduledoc "JSON routes that need a signed-in person answer 401 otherwise."
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_scope] do
      %{user: %{}} ->
        conn

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{"error" => "sign in first"})
        |> halt()
    end
  end
end
