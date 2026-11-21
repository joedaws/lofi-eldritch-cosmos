defmodule Eldritch.System.Volition do
  @moduledoc """
  The will of the beings. Every cycle each living being:

    1. checks its life (`Eldritch.Being.Life`): a commons being past its
       lifespan, or an owned being its owner has neglected, withers. Its psyche
       lives a tick too (`Eldritch.Lacan.tick/2`): lack grows, the knot of
       the registers loosens or reties
    2. fades if its ichor has run dry
    3. is placed somewhere if it is nowhere
    4. otherwise performs the highest priority action
       (`Eldritch.Being.Action`) whose preconditions hold
  """
  require Logger
  alias Eldritch.Entities

  @actions [
             Eldritch.Being.Actions.Consume,
             Eldritch.Being.Actions.ShiftDesire,
             Eldritch.Being.Actions.Anxiety,
             Eldritch.Being.Actions.Repetition,
             Eldritch.Being.Actions.Forage,
             Eldritch.Being.Actions.Linger,
             Eldritch.Being.Actions.MoveToResource,
             Eldritch.Being.Actions.SeekKin,
             Eldritch.Being.Actions.Explore
           ]
           |> Enum.sort_by(& &1.priority(), :desc)

  @wither 3
  # the least ichor an owned, remembered being can fall to
  @endure_ichor 15

  def actions(), do: @actions

  def update_components(_system) do
    graph = Entities.node_map()
    beings = Entities.being_list() |> Enum.filter(&Map.has_key?(&1, "volition"))
    living = Enum.filter(beings, &Entities.alive?/1)
    kin_at = Enum.group_by(living, & &1["at_node"])
    beings_by_id = Map.new(beings, &{&1["id"], &1})
    other = Eldritch.Lacan.big_other(beings)
    Eldritch.Lacan.store_big_other(other)

    shared = %{graph: graph, kin_at: kin_at, beings_by_id: beings_by_id, other: other}

    for being <- living do
      try do
        act(being, shared)
      catch
        kind, reason ->
          Logger.warning("#{being["name"]} could not act: #{Exception.format(kind, reason)}")
      end
    end

    Eldritch.Simulation.tick()
    dream(length(living), graph)
    crumble(beings)
  end

  defp act(being, shared) do
    ctx = Map.merge(shared, %{id: being["id"], pid: being["pid"], being: being})
    graph = ctx.graph
    elder = age(ctx)
    live_psyche(ctx)

    cond do
      # an owned being its owner keeps remembering cannot starve: it endures
      sustained?(being) ->
        Eldritch.Being.Actions.change_ichor(ctx.pid, @endure_ichor - (being["ichor"] || 0))
        think(ctx, {"endure", "I am nearly spent, yet something remembers me. I endure."})

      (being["ichor"] || 0) <= 0 ->
        Eldritch.Being.fade(being["id"], being)

      map_size(graph) == 0 ->
        :ok

      not Map.has_key?(graph, being["at_node"]) ->
        node_id = graph |> Map.keys() |> Enum.random()
        Eldritch.Being.Actions.move_to_node(being["id"], node_id)
        think(ctx, {"arrive", "I awaken in #{graph[node_id]["name"]}."})

      true ->
        if elder, do: Eldritch.Being.Actions.change_ichor(ctx.pid, -@wither)

        case Enum.find(@actions, & &1.preconditions_satisfied?(ctx)) do
          nil -> think(ctx, {"rest", "I rest."})
          action -> think(ctx, action.perform(ctx))
        end
    end
  end

  defp sustained?(being) do
    Eldritch.Being.owner(being) != nil and (being["ichor"] || 0) < @endure_ichor and
      Eldritch.Being.Life.condition(being) == :vital
  end

  # A dwindling cosmos dreams new beings: below `min_population` living
  # beings, the Heart of the Cosmos (or any place) brings forth a being of
  # the commons every `dream_interval_ticks`, so the cosmos cannot die out.
  defp dream(living, graph) do
    floor = Application.get_env(:eldritch, :min_population, 8)
    interval = Application.get_env(:eldritch, :dream_interval_ticks, 60)

    if living < floor and map_size(graph) > 0 and rem(Eldritch.Simulation.tick_count(), interval) == 0 do
      node =
        Enum.find_value(graph, fn {id, n} -> if n["name"] == "The Heart of the Cosmos", do: id end) ||
          graph |> Map.keys() |> Enum.random()

      id =
        Eldritch.Being.Builder.build({:new, :being, :standard}, %{
          "at_node" => node,
          "incantation" => Eldritch.KnowledgePack.random_incantation()
        })

      name = Cosmos.Entity.Cache.server_process(id) |> Cosmos.Entity.Server.value("name")

      Eldritch.Chronicle.record(
        :summon,
        "The cosmos, dwindling, dreams a new being: #{name} wakes in #{graph[node]["name"]}.",
        %{"beings" => [id], "node" => node}
      )
    end
  end

  # husks of faded commons beings crumble to dust after a while, so a cosmos
  # that runs for weeks is not buried in them
  defp crumble(beings) do
    for being <- beings, Eldritch.Being.Life.crumbled?(being) do
      Cosmos.Entity.Cache.stop(being["id"])
      Cosmos.Database.delete(being["id"])
    end

    # husks faded before fading was timed get a time now
    for %{"status" => "faded"} = being <- beings,
        get_in(being, ["lineage", "faded_at"]) == nil do
      Cosmos.Entity.Server.update_component(being["pid"], "lineage", fn comp ->
        %{comp | value: Map.put(comp.value, "faded_at", Eldritch.Being.Life.now())}
      end)
    end
  end

  defp live_psyche(ctx) do
    before = Eldritch.Lacan.unknotted(Eldritch.Lacan.normalize(ctx.being["psyche"]))
    starving = (ctx.being["ichor"] || 0) < 20
    desire = get_in(ctx.being, ["volition", "desire"])
    near_object = get_in(ctx.graph, [ctx.being["at_node"], "resource_type"]) == desire
    psyche = Eldritch.Lacan.update(ctx.pid, &Eldritch.Lacan.tick(&1, starving, near_object))
    now = psyche && Eldritch.Lacan.unknotted(psyche)

    cond do
      psyche == nil or now == before ->
        :ok

      now == nil ->
        Eldritch.Chronicle.record(:knot, "#{ctx.being["name"]}'s knot holds again.", %{
          "beings" => [ctx.id]
        })

      true ->
        Eldritch.Chronicle.record(
          :knot,
          "#{ctx.being["name"]}'s knot loosens: the #{String.capitalize(now)} overwhelms it.",
          %{"beings" => [ctx.id]}
        )
    end
  end

  # increments the being's age, returns true when it has outlived its lifespan
  # true when the being is withering (old age, or an owner's neglect);
  # the chronicle notes the moment it begins, once
  defp age(ctx) do
    case Eldritch.Being.Life.condition(ctx.being) do
      :vital ->
        false

      {:withering, :age} ->
        unless get_in(ctx.being, ["lineage", "elder_noted"]) do
          Cosmos.Entity.Server.update_component(ctx.pid, "lineage", fn comp ->
            %{comp | value: Map.put(comp.value, "elder_noted", true)}
          end)

          Eldritch.Chronicle.record(
            :elder,
            "#{ctx.being["name"]} has grown ancient. Its substance begins to thin.",
            %{"beings" => [ctx.id]}
          )
        end

        true

      {:withering, :neglect} ->
        unless get_in(ctx.being, ["ownership", "neglect_noted"]) do
          Cosmos.Entity.Server.update_component(ctx.pid, "ownership", fn comp ->
            %{comp | value: Map.put(comp.value, "neglect_noted", true)}
          end)

          Eldritch.Chronicle.record(
            :elder,
            "#{ctx.being["name"]} has gone unanswered too long. Its substance begins to thin.",
            %{"beings" => [ctx.id]}
          )
        end

        true
    end
  end

  defp think(ctx, {intent, thought}) do
    Cosmos.Entity.Server.update_component(ctx.pid, "volition", fn comp ->
      %{comp | value: Map.merge(comp.value, %{"intent" => intent, "thought" => thought})}
    end)
  end
end
