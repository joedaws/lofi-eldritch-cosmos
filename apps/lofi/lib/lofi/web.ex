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
    case response do
      "" -> send_resp(conn, 200, Poison.encode!("No beings"))
      beings -> send_resp(conn, 200, Poison.encode!(response))
    end
  end

  get "/being" do
    conn = Plug.Conn.fetch_query_params(conn)
    being_id = Map.fetch!(conn.params, "id")
    response = Eldritch.Being.get(being_id)
    send_resp(conn, 200, Poison.encode!(response))
  end

  post "/c" do
    test_c = %{"you"=>"reached here"}
    send_resp(conn, 200, Poison.encode!(test_c))
  end

  @doc """
  The following curl workds on this route
  curl -X POST -H "Content-Type: application/json" -d '{"incantation":{"front":"value1", "back":"value2"}}' http://localhost:5454/b

  See https://medium.com/@jonlunsford/elixir-building-a-small-json-endpoint-with-plug-cowboy-and-poison-f4bb40c23bf6
  for an example of testing the endpoints too
  """
  post "/b" do
    {status, body} =
      case conn.body_params do
        %{"incantation"=>%{"front"=>front, "back"=>back}} -> {200, Poison.encode!(%{"response"=> "yeah_buddy"})}
        _ -> {400, Poison.encode!%{error: "Unkown params"}}
      end
    send_resp(conn, status, body)
  end

  post "/being" do
    conn
    |> parse_json()
    |> handle_invocation()
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "not found")
  end

  defp parse_json(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    Logger.info("Parsed json body #{body}")
    case Poison.decode(body) do
      {:ok, params} -> {conn, params}
      {:error, _} -> conn |> send_resp(400, "Bad Request") |> halt()
    end
  end

  defp handle_invocation({conn, %{"invocation" => %{"front" => front, "back" => back}}}) do
    being_id = Eldritch.Being.Builder.build({:new, :being, :standard})
    Logger.info("starting update to being #{being_id}")
    Eldritch.Being.update(being_id, "incantation", fn comp ->
      Map.update!(comp, :value, fn _ -> %{"front"=>front, "back"=>back} end)
    end)
    conn
    |> send_resp(200, Poison.encode!(%{"message" => "#{being_id} updated invocation"}))
  end

  defp handle_invocation({conn, _}) do
    conn
    |> send_resp(400, "Invalid data")
  end

end
