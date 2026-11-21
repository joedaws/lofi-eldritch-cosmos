defmodule Eldritch.Being.Actions.Explore do
  @moduledoc """
  Visit previously unvisited locations, or wander when every
  neighbouring place is already known.
  """
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action

  @impl true
  def priority(), do: 4

  @impl true
  def preconditions_satisfied?(ctx), do: neighbors(ctx) != []

  @impl true
  def perform(ctx) do
    # a homebody sometimes stays where it is instead of wandering
    homebody = max(0, 50 - Eldritch.Being.Temperament.trait(ctx.being, "wanderlust")) / 100

    if :rand.uniform() < homebody do
      {"rest", "I stay in #{node_name(ctx, ctx.being["at_node"])}. It is enough."}
    else
      wander(ctx)
    end
  end

  defp wander(ctx) do
    visited = visited(ctx)
    options = neighbors(ctx)

    case Enum.reject(options, &Map.has_key?(visited, &1)) do
      [] ->
        node_id = Enum.random(options)
        move(ctx, node_id)
        {"wander", "I wander to #{node_name(ctx, node_id)}."}

      unvisited ->
        node_id = Enum.random(unvisited)
        move(ctx, node_id)
        {"explore", "I venture into #{node_name(ctx, node_id)}, unknown to me."}
    end
  end
end
