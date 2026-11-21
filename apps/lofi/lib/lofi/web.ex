defmodule Lofi.Web do
  @moduledoc """
  The Lofi application is the intermediary between
  a user and the underlying Eldritch application.
  The lofi server should interact only with the eldritch
  application and not the Cosmos application so that
  it only cares about the implementation of the Eldritch application
  not the Cosmos application. This insulates Lofi from changes
  in the way the database is setup.

  `GET /` serves the visualization of the cosmos.
  """

  use Plug.Router
  require Logger

  # Using Plug.Logger for logging request information
  plug(Plug.Logger, log: :debug)
  plug(Plug.Static, at: "/static", from: {:lofi, "priv/static"})
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(:dispatch)

  def child_spec(_arg) do
    port = Application.fetch_env!(:lofi, :http_port)
    Logger.info("lofi server listening on http://localhost:#{port}")

    Plug.Cowboy.child_spec(
      scheme: :http,
      options: [port: port],
      plug: __MODULE__
    )
  end

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Application.app_dir(:lofi, "priv/static/index.html"))
  end

  get "/ping" do
    json(conn, 200, %{"message" => "You have reached the lofi-eldritch-cosmos"})
  end

  # The whole cosmos: nodes, beings, simulation status and chronicle
  # events newer than the optional `since` sequence number.
  get "/world" do
    conn = fetch_query_params(conn)
    since = conn.params |> Map.get("since", "0") |> parse_int(0)
    json(conn, 200, Eldritch.World.snapshot(since: since))
  end

  get "/being" do
    conn = fetch_query_params(conn)

    case Eldritch.Being.fetch(Map.get(conn.params, "id")) do
      {:ok, entity} -> json(conn, 200, Eldritch.Entities.to_json(entity))
      :error -> json(conn, 404, %{"error" => "no such being"})
    end
  end

  # returns list of being_ids
  get "/beings" do
    json(conn, 200, Eldritch.query("beings"))
  end

  get "/nodes" do
    json(conn, 200, Eldritch.query("nodes"))
  end

  # Creates a being. Every field is optional:
  #
  #   curl -X POST http://localhost:5454/being
  #   curl -X POST -H "Content-Type: application/json" \
  #     -d '{"name": "Gor Lop~Ga", "at_node": "...", "incantation": {"front": "value1", "back": "value2"}}' \
  #     http://localhost:5454/being
  post "/being" do
    params = conn.body_params

    with {:ok, attributes} <- being_attributes(params) do
      being_id = Eldritch.Being.Builder.build({:new, :being, :standard}, attributes)
      Logger.info("created being #{being_id}")
      name = Eldritch.Being.component(being_id, "name").value

      Eldritch.Chronicle.record(:summon, "#{name} is summoned by an unseen hand.", %{
        "beings" => [being_id],
        "node" => attributes["at_node"]
      })

      json(conn, 200, %{"message" => "Created being", "being_id" => being_id})
    else
      {:error, message} -> json(conn, 400, %{"error" => message})
    end
  end

  # Answer the incantation a being is whispering: {"id": ..., "answer": ...}
  post "/being/recall" do
    params = conn.body_params

    case Eldritch.Being.recall(params["id"], to_string(params["answer"] || "")) do
      {:ok, result} ->
        json(conn, 200, result)

      {:error, :not_awaiting, due_in} ->
        json(conn, 409, %{"error" => "the being is not whispering yet", "due_in_ms" => due_in})

      :error ->
        json(conn, 404, %{"error" => "no such being"})
    end
  end

  # Draw a being to a node: {"id": ..., "node_id": ...}
  post "/being/beckon" do
    params = conn.body_params

    case Eldritch.Being.beckon(params["id"], params["node_id"]) do
      :ok -> json(conn, 200, %{"message" => "the being heeds your call"})
      :error -> json(conn, 404, %{"error" => "no such being"})
      {:error, reason} -> json(conn, 400, %{"error" => to_string(reason)})
    end
  end

  # Replace a being's incantation: {"id": ..., "front": ..., "back": ...}
  post "/being/incantation" do
    params = conn.body_params

    case Eldritch.Being.set_incantation(params["id"], params["front"], params["back"]) do
      :ok -> json(conn, 200, %{"message" => "the incantation is bound"})
      :error -> json(conn, 404, %{"error" => "no such being"})
    end
  end

  get "/simulation" do
    json(conn, 200, Eldritch.Simulation.status())
  end

  post "/simulation/start" do
    Eldritch.Simulation.start()
    json(conn, 200, Eldritch.Simulation.status())
  end

  post "/simulation/stop" do
    Eldritch.Simulation.stop()
    json(conn, 200, Eldritch.Simulation.status())
  end

  # {"tick_ms": 500}
  post "/simulation/speed" do
    case parse_int(conn.body_params["tick_ms"], nil) do
      nil ->
        json(conn, 400, %{"error" => "tick_ms must be an integer"})

      tick_ms ->
        Eldritch.Simulation.set_tick_ms(tick_ms)
        json(conn, 200, Eldritch.Simulation.status())
    end
  end

  # Seed a landscape with beings: {"beings": 12, "rings": [6, 10, 14], "reset": true}
  post "/cosmos/seed" do
    params = conn.body_params

    if params["reset"] in [true, "true"], do: Eldritch.Genesis.reset()

    opts =
      [
        beings: parse_int(params["beings"], 12) |> max(0) |> min(60),
        rings:
          case params["rings"] do
            rings when is_list(rings) and rings != [] ->
              rings |> Enum.map(&(parse_int(&1, 6) |> max(1) |> min(40))) |> Enum.take(6)

            _ ->
              [6, 10, 14]
          end
      ]

    result = Eldritch.Genesis.seed(opts)

    json(conn, 200, %{
      "nodes" => length(result["node_ids"]),
      "beings" => length(result["being_ids"])
    })
  end

  post "/cosmos/reset" do
    count = Eldritch.Genesis.reset()
    json(conn, 200, %{"removed" => count})
  end

  match _ do
    json(conn, 404, %{"error" => "not found"})
  end

  defp being_attributes(params) when is_map(params) do
    attributes =
      params
      |> Map.take(["name", "at_node"])
      |> Enum.reject(fn {_, v} -> v in [nil, ""] end)
      |> Map.new()

    case params["incantation"] do
      nil ->
        {:ok, attributes}

      %{"front" => front, "back" => back} ->
        {:ok, Map.put(attributes, "incantation", %{"front" => front, "back" => back})}

      %{"front" => front} ->
        {:ok, Map.put(attributes, "incantation", %{"front" => front, "back" => ""})}

      _ ->
        {:error, "incantation needs a front (and optionally a back)"}
    end
  end

  defp json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Poison.encode!(body))
  end

  defp parse_int(value, _default) when is_integer(value), do: value

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_int(_, default), do: default
end
