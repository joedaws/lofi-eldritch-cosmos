defmodule Lofi.Web do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  def child_spec(_arg) do
    Plug.Adapters.Cowboy.child_spec(
      scheme: :http,
      options: [port: 5454],
      plug: __MODULE__
    )
  end

  # curl 'http://localhost:5454/entity?entity_id={entity_id}'
  get "/entity" do
    conn = Plug.Conn.fetch_query_params(conn)
    entity_id = Map.fetch!(conn.params, "entity_id")

    entity =
      entity_id
      |> Cosmos.Entity.Cache.server_process()
      |> Cosmos.Entity.Server.get()

    formatted_entity = to_string(entity)

    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, formatted_entity)
  end

  """
  Route to add a component to a being

  For example
  curl -d '' 'http://localhost:5454/add_component?\
  entity_id=1111&name=grimoire&system=attribute&value=oneirona'
  """

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
