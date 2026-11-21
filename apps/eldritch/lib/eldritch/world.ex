defmodule Eldritch.World do
  @moduledoc """
  A JSON friendly picture of the whole cosmos, used by the
  visualization and the http api.
  """
  alias Eldritch.Entities

  @doc """
  Options:
    * `:since`  - only chronicle events after this sequence number
    * `:viewer` - id of the person looking (nil when anonymous). Card fronts
      show only to whoever may answer them: a being's owner, or anyone
      signed in for the beings of the commons.
  """
  def snapshot(opts \\ []) do
    since = Keyword.get(opts, :since, 0)
    viewer = Keyword.get(opts, :viewer)
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
      "beings" => Enum.map(beings, &being_view(&1, viewer)),
      "events" => Eldritch.Chronicle.since(since, 100),
      "resources" => Eldritch.Node.Resource.get_resource_types(),
      # what the cosmos as a whole desires (see Eldritch.Lacan.big_other/1)
      "big_other" => Eldritch.Lacan.stored_big_other()
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

  def psyche_view(psyche) do
    p = Eldritch.Lacan.normalize(psyche)

    %{
      # the cause of desire is hidden, even from the owner, until anxiety reveals it
      "objet_a" => if(p["objet_a_revealed"], do: p["objet_a"], else: nil),
      "chain" => p["chain"],
      "lack" => round(p["lack"]),
      "jouissance" => round(p["jouissance"]),
      "registers" => Map.new(p["registers"], fn {k, v} -> {k, Float.round(v * 1.0, 3)} end),
      "unknotted" => Eldritch.Lacan.unknotted(p),
      "identification" => p["identification"],
      "symptom" => p["symptom"],
      "reason" => p["reason"]
    }
  end

  # ages in milliseconds of real time; owned beings have no lifespan, only
  # the grace their owner's last answer bought them
  def lineage_view(b) do
    lineage = Eldritch.Being.Life.normalize(b["lineage"])
    owned = Eldritch.Being.owner(b) != nil

    %{
      "generation" => lineage["generation"],
      "parents" => lineage["parents"],
      "age_ms" => Eldritch.Being.Life.age_ms(lineage),
      "lifespan_ms" => if(owned, do: nil, else: lineage["lifespan_ms"]),
      "grace_left_ms" => if(owned, do: Eldritch.Being.Life.grace_left_ms(b), else: nil),
      "withering" => Eldritch.Being.Life.condition(b) != :vital
    }
  end

  def being_view(b, viewer \\ nil) do
    deck = Eldritch.Being.Deck.normalize(b["deck"] || b["incantation"])
    card = Eldritch.Being.Deck.current(deck) || %{}
    owner = Eldritch.Being.owner(b)
    signed_in = viewer != nil
    can_answer = signed_in and Eldritch.Being.may_answer(b, viewer) == :ok

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
      "lineage" => lineage_view(b),
      "psyche" => psyche_view(b["psyche"]),
      "temperament" => Eldritch.Being.Temperament.new(b["temperament"] || %{}),
      "owner_id" => owner,
      "mine" => signed_in and owner == viewer,
      "can_answer" => can_answer,
      "deck_size" => length(deck["cards"]),
      "beckon_wait_ms" => if(signed_in and owner == viewer, do: Eldritch.Being.Owned.beckon_wait(b), else: nil),
      "incantation" => %{
        # a card belongs to its owner: its words show only to whoever may answer it
        "front" => if(can_answer or owner == nil, do: card["front"], else: nil),
        "has_back" => (card["back"] || "") != "",
        "box" => card["box"],
        "due_at" => card["due_at"],
        "awaiting" => card["awaiting"] || false,
        "streak" => card["streak"]
      }
    }
  end
end
