defmodule Eldritch.Being.Actions.Linger do
  @moduledoc "A being stays to gather where its desired resource is still plentiful."
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action

  @impl true
  def priority(), do: 8

  @impl true
  def preconditions_satisfied?(ctx) do
    restless = max(0, Eldritch.Being.Temperament.trait(ctx.being, "wanderlust") - 50) / 100

    case here(ctx) do
      nil -> false
      node -> node["resource_type"] == desire(ctx) and reserve(node) > 0 and :rand.uniform() >= restless
    end
  end

  @impl true
  def perform(ctx) do
    {"gather", "I gather #{pretty(desire(ctx))} at #{node_name(ctx, ctx.being["at_node"])}."}
  end
end
