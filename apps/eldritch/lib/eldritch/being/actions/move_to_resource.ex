defmodule Eldritch.Being.Actions.MoveToResource do
  @moduledoc """
  A being travels (one node per cycle) toward the nearest node it knows
  of that holds the resource it desires.
  """
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action

  @impl true
  def priority(), do: 7

  @impl true
  def preconditions_satisfied?(ctx), do: destinations(ctx) != []

  @impl true
  def perform(ctx) do
    case next_hop(ctx, ctx.being["at_node"], destinations(ctx)) do
      nil ->
        {"lost", "I know where #{pretty(desire(ctx))} lies, but cannot find the way."}

      hop ->
        move(ctx, hop)
        {"travel", "I travel toward #{pretty(desire(ctx))}, through #{node_name(ctx, hop)}."}
    end
  end

  defp destinations(ctx) do
    desire = desire(ctx)
    here = ctx.being["at_node"]

    for {node_id, resource} <- known_nodes(ctx),
        resource == desire,
        node_id != here,
        reserve(Map.get(ctx.graph, node_id, %{})) > 0,
        do: node_id
  end
end
