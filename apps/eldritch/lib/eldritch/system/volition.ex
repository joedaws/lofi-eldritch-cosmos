defmodule Eldritch.System.Volition do
  @moduledoc """
  The will of the beings. Every cycle each living being:

    1. ages by one cycle; past its lifespan its ichor withers
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
             Eldritch.Being.Actions.Forage,
             Eldritch.Being.Actions.Linger,
             Eldritch.Being.Actions.MoveToResource,
             Eldritch.Being.Actions.SeekKin,
             Eldritch.Being.Actions.Explore
           ]
           |> Enum.sort_by(& &1.priority(), :desc)

  @wither 3

  def actions(), do: @actions

  def update_components(_system) do
    graph = Entities.node_map()
    beings = Entities.being_list() |> Enum.filter(&Map.has_key?(&1, "volition"))
    living = Enum.filter(beings, &Entities.alive?/1)
    kin_at = Enum.group_by(living, & &1["at_node"])

    for being <- living do
      try do
        act(being, graph, kin_at)
      catch
        kind, reason ->
          Logger.warning("#{being["name"]} could not act: #{Exception.format(kind, reason)}")
      end
    end

    Eldritch.Simulation.tick()
  end

  defp act(being, graph, kin_at) do
    ctx = %{id: being["id"], pid: being["pid"], being: being, graph: graph, kin_at: kin_at}
    elder = age(ctx)

    cond do
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

  # increments the being's age, returns true when it has outlived its lifespan
  defp age(ctx) do
    lineage = ctx.being["lineage"] || %{}
    age = Map.get(lineage, "age", 0) + 1
    lifespan = Map.get(lineage, "lifespan", Eldritch.Being.Builder.default_lifespan())

    Cosmos.Entity.Server.update_component(ctx.pid, "lineage", fn comp ->
      %{comp | value: Map.merge(comp.value, %{"age" => age, "lifespan" => lifespan})}
    end)

    if age == lifespan do
      Eldritch.Chronicle.record(
        :elder,
        "#{ctx.being["name"]} has grown ancient. Its substance begins to thin.",
        %{"beings" => [ctx.id]}
      )
    end

    age > lifespan
  end

  defp think(ctx, {intent, thought}) do
    Cosmos.Entity.Server.update_component(ctx.pid, "volition", fn comp ->
      %{comp | value: Map.merge(comp.value, %{"intent" => intent, "thought" => thought})}
    end)
  end
end
