defmodule Eldritch.Being.Actions.Forage do
  @moduledoc """
  A starving being with nothing to eat gathers whatever is at hand or
  stumbles to the richest neighbouring node.
  """
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action

  @starving 40

  @impl true
  def priority(), do: 8.5

  @impl true
  def preconditions_satisfied?(ctx) do
    ichor(ctx) < @starving and map_size(resources(ctx)) == 0 and here(ctx) != nil
  end

  @impl true
  def perform(ctx) do
    here = here(ctx)

    best =
      ctx
      |> neighbors()
      |> Enum.max_by(&reserve(ctx.graph[&1]), fn -> nil end)

    cond do
      reserve(here) > 0 ->
        {"forage", "Starving, I scrape at the #{pretty(here["resource_type"])} here."}

      best != nil ->
        move(ctx, best)
        {"forage", "Starving, I stumble toward #{node_name(ctx, best)}."}

      true ->
        {"forage", "There is nothing left. I wait."}
    end
  end
end
