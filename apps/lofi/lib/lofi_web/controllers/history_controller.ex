defmodule LofiWeb.HistoryController do
  @moduledoc """
  A person's own history: what they did with their being, how well they
  remember each card, and what happened to their being. Nobody else can
  read it.
  """
  use LofiWeb, :controller
  import LofiWeb.ApiHelpers
  alias Eldritch.History

  # recent activity for the journal: ?limit=50&before=<interaction id>
  def show(conn, params) do
    owner = user_id(conn)
    limit = parse_int(params["limit"], 50) |> max(1) |> min(200)
    before = parse_int(params["before"], nil)
    being = Eldritch.Being.Owned.being_of(owner)

    json(conn, %{
      "interactions" => History.interactions(owner, limit: limit, before: before),
      "cards" => Lofi.Agent.accuracy(owner),
      "being_events" => if(being, do: History.being_events(being["id"], 30), else: [])
    })
  end

  # everything, one JSON object per line, for a person's own tools and agents
  def export(conn, _params) do
    owner = user_id(conn)
    lines = owner |> History.export() |> Enum.map_join("\n", &Jason.encode!/1)
    date = Date.utc_today() |> Date.to_iso8601()

    conn
    |> put_resp_content_type("application/x-ndjson")
    |> put_resp_header("content-disposition", ~s(attachment; filename="lofi-eldritch-history-#{date}.jsonl"))
    |> send_resp(200, if(lines == "", do: "", else: lines <> "\n"))
  end

end
