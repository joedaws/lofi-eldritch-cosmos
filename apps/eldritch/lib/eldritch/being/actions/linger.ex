defmodule Eldritch.Being.Actions.Linger do
  @moduledoc "A being stays to gather where its desired resource is still plentiful."
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action

  @impl true
  def priority(), do: 8

  @impl true
  def preconditions_satisfied?(ctx) do
    case here(ctx) do
      nil -> false
      node -> node["resource_type"] == desire(ctx) and reserve(node) > 0
    end
  end

  @impl true
  def perform(ctx) do
    {"gather", "I gather #{pretty(desire(ctx))} at #{node_name(ctx, ctx.being["at_node"])}."}
  end
end
