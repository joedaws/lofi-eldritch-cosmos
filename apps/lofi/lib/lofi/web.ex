defmodule Lofi.Web do
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
    response = Cosmos.query("beings")
    send_resp(conn, 200, Poison.encode!(response))
  end

  get "/being" do
    conn = Plug.Conn.fetch_query_params(conn)
    being_id = Map.fetch!(conn.params, "id")
    response =
      Cosmos.Entity.Cache.server_process(being_id)
      |> Cosmos.Entity.Server.get()
    send_resp(conn, 200, Poison.encode!(response))
  end

  # Can be used to increase or descrease a component with a numerical value
  # curl 'http://localhost:5454/numeric_delta?entity_id={entity_id}&component_name=ichor&delta=10'
  # delta can be positive or negative
  get "/numeric_delta" do
    conn = Plug.Conn.fetch_query_params(conn)
    entity_id = Map.fetch!(conn.params, "entity_id")

    entity_id
    |> Cosmos.Entity.Cache.server_process()
    |> Cosmos.Entity.Server.update_component("ichor", fn x ->
      Cosmos.Entity.Component.update_numeric_value(x, 10)
    end)

    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "OK")
  end

  # curl 'http://localhost:5454/components?entity_id={entity_id}'
  get "/components" do
    conn = Plug.Conn.fetch_query_params(conn)
    entity_id = Map.fetch!(conn.params, "entity_id")

    # There should only ever at most one ichor component
    ichor_component =
      entity_id
      |> Cosmos.Entity.Cache.server_process()
      |> Cosmos.Entity.Server.get()
      |> Cosmos.Entity.component("ichor")
      |> Enum.at(0)

    formatted_ichor = "#{ichor_component.value}"

    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, formatted_ichor)
  end

  post "/being" do
    being_id = Eldritch.Being.Builder.build({:new, :being, :standard})
    response =  %{"being_id" => being_id}
    send_resp(conn, 200, Poison.encode!(response))
  end

  # curl -d '' 'http://localhost:5454/add_component?\
  # entity_id=1111&name=grimoire&system=attribute&value=oneirona'

  post "/add_component" do
    conn = Plug.Conn.fetch_query_params(conn)
    entity_id = Map.fetch!(conn.params, "entity_id")
    name = Map.fetch!(conn.params, "name")
    system = Map.fetch!(conn.params, "system")
    value = Map.fetch!(conn.params, "value")

    entity_id
    |> Cosmos.Entity.Cache.server_process()
    |> Cosmos.Entity.Server.add_component(
      Cosmos.Entity.Component.new(
        name,
        system,
        value
      )
    )

    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "OK")
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "not found")
  end

end
