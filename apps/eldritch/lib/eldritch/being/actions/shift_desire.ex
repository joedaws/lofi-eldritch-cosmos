defmodule Eldritch.Being.Actions.ShiftDesire do
  @moduledoc """
  Desire is never satisfied by its object: once a being has hoarded
  enough of what it wanted it devours the hoard (gaining ichor), yet
  its longing simply slides on to something it does not have.
  """
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action

  @enough 30
  @feast_ichor 30

  @impl true
  def priority(), do: 9

  @impl true
  def preconditions_satisfied?(ctx) do
    Map.get(resources(ctx), desire(ctx), 0) >= @enough
  end

  @impl true
  def perform(ctx) do
    old = desire(ctx)
    resources = resources(ctx)

    devoured = Eldritch.Being.Actions.take_resource(ctx.pid, old, @enough)
    Eldritch.Being.Actions.change_ichor(ctx.pid, @feast_ichor)

    candidates =
      Eldritch.Node.Resource.get_resource_types()
      |> Enum.reject(&(&1 == old or Map.get(resources, &1, 0) >= @enough))

    new =
      Enum.random(
        if candidates == [],
          do: List.delete(Eldritch.Node.Resource.get_resource_types(), old),
          else: candidates
      )

    Cosmos.Entity.Server.update_component(ctx.pid, "volition", fn comp ->
      %{comp | value: Map.put(comp.value, "desire", new)}
    end)

    Eldritch.Chronicle.record(
      :desire,
      "#{ctx.being["name"]} devours its hoard of #{devoured} #{pretty(old)}, yet still it lacks. Now it longs for #{pretty(new)}.",
      %{"beings" => [ctx.id]}
    )

    {"yearn", "#{String.capitalize(pretty(old))} no longer satisfies. I long for #{pretty(new)}."}
  end
end
