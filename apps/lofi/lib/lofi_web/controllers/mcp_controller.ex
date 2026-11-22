defmodule LofiWeb.McpController do
  @moduledoc """
  A Model Context Protocol server (Streamable HTTP transport, JSON
  responses) so a person's learning agent can follow their being and help
  them study. Tools come from `Lofi.Agent`. Authenticated with an agent
  token: `Authorization: Bearer lofi_agent_…`.

  Supports `initialize`, `ping`, `tools/list` and `tools/call`; notifications
  are accepted with 202. There is no server-initiated stream (GET answers 405).
  """
  use LofiWeb, :controller
  require Logger

  @versions ["2025-06-18", "2025-03-26", "2024-11-05"]

  def rpc(conn, params) do
    case params do
      %{"_json" => batch} when is_list(batch) ->
        replies = batch |> Enum.map(&handle(conn, &1)) |> Enum.reject(&is_nil/1)
        if replies == [], do: send_resp(conn, 202, ""), else: json(conn, replies)

      message ->
        case handle(conn, message) do
          nil -> send_resp(conn, 202, "")
          reply -> json(conn, reply)
        end
    end
  end

  def stream(conn, _params) do
    conn
    |> put_resp_header("allow", "POST")
    |> send_resp(405, "")
  end

  # notifications and responses (no id) need no reply
  defp handle(_conn, %{"method" => "notifications/" <> _}), do: nil
  defp handle(_conn, %{"jsonrpc" => "2.0", "method" => _} = msg) when not is_map_key(msg, "id"), do: nil

  defp handle(conn, %{"jsonrpc" => "2.0", "id" => id, "method" => method} = msg) do
    case dispatch(conn, method, Map.get(msg, "params", %{})) do
      {:ok, result} -> %{"jsonrpc" => "2.0", "id" => id, "result" => result}
      {:error, code, message} -> %{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}}
    end
  end

  defp handle(_conn, %{"id" => id}),
    do: %{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => -32600, "message" => "invalid request"}}

  defp handle(_conn, _),
    do: %{"jsonrpc" => "2.0", "id" => nil, "error" => %{"code" => -32600, "message" => "invalid request"}}

  defp dispatch(_conn, "initialize", params) do
    requested = params["protocolVersion"]

    {:ok,
     %{
       "protocolVersion" => if(requested in @versions, do: requested, else: hd(@versions)),
       "capabilities" => %{"tools" => %{"listChanged" => false}},
       "serverInfo" => %{"name" => "lofi-eldritch-cosmos", "version" => app_version()},
       "instructions" =>
         "This is the person's window into the Lofi Eldritch Cosmos, where a being they own lives " <>
           "on their remembering. Its deck of incantations is their study material: use my_cards, " <>
           "card_accuracy and whispering_now to help them learn, for example by quizzing them on " <>
           "their weakest cards or on the card being whispered. You may add, rewrite and burn cards " <>
           "when they ask. You cannot answer whispers for them: in the cosmos only the person's own " <>
           "answer counts. Use explain for the cosmos's concepts."
     }}
  end

  defp dispatch(_conn, "ping", _params), do: {:ok, %{}}

  defp dispatch(_conn, "tools/list", _params), do: {:ok, %{"tools" => Lofi.Agent.tools()}}

  defp dispatch(conn, "tools/call", %{"name" => name} = params) do
    %{agent_user: user, agent_token: token} = conn.assigns
    args = Map.get(params, "arguments") || %{}

    result =
      try do
        Lofi.Agent.call(user, name, args, "agent: #{token.name}")
      rescue
        error ->
          Logger.error("agent tool #{name} failed: #{Exception.message(error)}")
          {:error, "the tool failed"}
      end

    case result do
      {:ok, value} ->
        {:ok,
         %{
           "content" => [%{"type" => "text", "text" => Jason.encode!(value, pretty: true)}],
           "structuredContent" => %{"result" => value},
           "isError" => false
         }}

      {:error, "unknown tool" <> _ = message} ->
        {:error, -32602, message}

      {:error, message} ->
        {:ok, %{"content" => [%{"type" => "text", "text" => message}], "isError" => true}}
    end
  end

  defp dispatch(_conn, "tools/call", _params), do: {:error, -32602, "tools/call needs a name"}
  defp dispatch(_conn, method, _params), do: {:error, -32601, "method not found: #{method}"}

  defp app_version(), do: :lofi |> Application.spec(:vsn) |> to_string()
end
