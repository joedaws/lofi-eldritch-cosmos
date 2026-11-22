defmodule LofiWeb.Plugs.AgentAuth do
  @moduledoc """
  Recognises a learning agent by its token (`Authorization: Bearer lofi_agent_…`).
  Assigns `:agent_user` and `:agent_token`, or answers 401.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {user, agent_token} <- Lofi.Accounts.get_user_by_agent_token(String.trim(token)) do
      conn |> assign(:agent_user, user) |> assign(:agent_token, agent_token)
    else
      _ ->
        conn
        |> put_resp_header("www-authenticate", ~s(Bearer realm="lofi-eldritch-cosmos"))
        |> put_status(:unauthorized)
        |> json(%{"error" => "a valid agent token is required (Authorization: Bearer lofi_agent_…)"})
        |> halt()
    end
  end
end
