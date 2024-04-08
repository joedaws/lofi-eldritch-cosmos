defmodule Lofi.Web do

  @moduledoc """
  The Lofi application is the intermediary between
  a user and the underlying Eldritch application.
  The lofi server should interact only with the eldritch
  application and not the Cosmos application so that
  it only cares about the implementation of the Eldritch application
  not the Cosmos application. This insulates Lofi from changes
  in the way the database is setup.
  """

  use Plug.Router
  require Logger

  # Using Plug.Logger for logging request information
  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)

  plug(:dispatch)

  def child_spec(_arg) do
    port = Application.fetch_env!(:lofi, :http_port)
    Logger.info("lofi server port #{port}")

    Plug.Adapters.Cowboy.child_spec(
      scheme: :http,
      options: [port: port],
      plug: __MODULE__
    )
  end

  get "/ping" do
    send_resp(conn, 200, Poison.encode!(
          %{"message" => "You have reached the lofi-eldritch-cosmos"})
    )
  end

  get "/beings" do
    response = Eldritch.query("beings")
    send_resp(conn, 200, Poison.encode!(response))
  end

  get "/being" do
    conn = Plug.Conn.fetch_query_params(conn)
    being_id = Map.fetch!(conn.params, "id")
    response = Eldritch.Being.get(being_id)
    send_resp(conn, 200, Poison.encode!(response))
  end

  post "/being" do
    being_id = Eldritch.Being.Builder.build({:new, :being, :standard})
    response =  %{"being_id" => being_id}
    send_resp(conn, 200, Poison.encode!(response))
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "not found")
  end

end
