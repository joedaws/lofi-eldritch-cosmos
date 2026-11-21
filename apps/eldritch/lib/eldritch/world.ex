defmodule Eldritch.World do
  @moduledoc """
  A JSON friendly picture of the whole cosmos, used by the
  visualization and the http api.
  """
  alias Eldritch.Entities

  def snapshot(opts \\ []) do
    since = Keyword.get(opts, :since, 0)
    nodes = Entities.node_map()
    beings = Entities.being_list()
    living = Enum.count(beings, &Entities.alive?/1)

    %{
      "simulation" =>
        Map.merge(Eldritch.Simulation.status(), %{
          "population" => living,
          "faded" => length(beings) - living,
          "max_population" => Eldritch.System.Communion.max_population(),
          # the clock incantation due times are measured against
          "now" => Eldritch.Clock.now_ms()
        }),
      "nodes" => nodes |> Map.values() |> Enum.map(&node_view/1),
      "beings" => Enum.map(beings, &being_view/1),
      "events" => Eldritch.Chronicle.since(since, 100),
      "resources" => Eldritch.Node.Resource.get_resource_types()
    }
  end

  def node_view(n) do
    %{
      "id" => n["id"],
      "name" => n["name"],
      "resource_type" => n["resource_type"],
      "resource_yield" => n["resource_yield"],
      "reserve" => get_in(n, ["reserve", "amount"]) || 0,
      "max_reserve" => get_in(n, ["reserve", "max"]) || 0,
      "position" => n["position"],
      "neighbors" => n |> Map.get("neighbors", MapSet.new()) |> Enum.to_list(),
      "occupants" => n |> Map.get("occupants", MapSet.new()) |> Enum.to_list()
    }
  end

  def being_view(b) do
    incantation = Eldritch.Being.Incantation.normalize(b["incantation"] || %{})

    %{
      "id" => b["id"],
      "name" => b["name"],
      "status" => b["status"] || "alive",
      "ichor" => b["ichor"] || 0,
      "max_ichor" => Eldritch.Being.max_ichor(),
      "at_node" => b["at_node"],
      "orichalcum" => get_in(b, ["inventory", "orichalcum"]) || 0,
      "resources" => get_in(b, ["inventory", "resources"]) || %{},
      "desire" => get_in(b, ["volition", "desire"]),
      "intent" => get_in(b, ["volition", "intent"]),
      "thought" => get_in(b, ["volition", "thought"]),
      "bonds" => b["bonds"] || %{},
      "known_nodes" => map_size(get_in(b, ["observations", "nodes"]) || %{}),
      "visited_nodes" => map_size(get_in(b, ["observations", "visited"]) || %{}),
      "lineage" => b["lineage"] || %{"generation" => 0, "parents" => []},
      "incantation" => %{
        "front" => incantation["front"],
        # the answer is only revealed through recall
        "has_back" => incantation["back"] != "",
        "box" => incantation["box"],
        "due_at" => incantation["due_at"],
        "awaiting" => incantation["awaiting"],
        "streak" => incantation["streak"]
      }
    }
  end
end
