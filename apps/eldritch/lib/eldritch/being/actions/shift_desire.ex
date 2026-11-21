defmodule Eldritch.Being.Actions.ShiftDesire do
  @moduledoc """
  Desire is never satisfied by its object: once a being has hoarded
  enough of what it wanted it devours the hoard (jouissance), its lack
  falls for a while, and its desire slides metonymically to another
  object (see `Eldritch.Lacan.next_desire/3`): what the big Other
  desires, what its semblable desires, an old signifier returning, or
  whatever lay beside it.
  """
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action
  alias Eldritch.Lacan

  @enough 20
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
    psyche = psyche(ctx)

    devoured = Eldritch.Being.Actions.take_resource(ctx.pid, old, @enough)
    Eldritch.Being.Actions.change_ichor(ctx.pid, @feast_ichor)

    semblable = Map.get(ctx.beings_by_id, psyche["identification"])

    {new, reason} =
      Lacan.next_desire(psyche, old, %{
        other: ctx.other,
        semblable_desire: semblable && get_in(semblable, ["volition", "desire"]),
        semblable_name: semblable && semblable["name"],
        conformity: Eldritch.Being.Temperament.factor(ctx.being, "conformity"),
        contiguous:
          ctx |> neighbors() |> Enum.map(&get_in(ctx.graph, [&1, "resource_type"])) |> Enum.uniq()
      })

    Cosmos.Entity.Server.update_component(ctx.pid, "volition", fn comp ->
      %{comp | value: Map.put(comp.value, "desire", new)}
    end)

    Lacan.update(ctx.pid, fn p -> p |> Lacan.attain() |> Lacan.slide(old, new, reason) end)

    Eldritch.Chronicle.record(
      :desire,
      "#{ctx.being["name"]} devours its hoard of #{devoured} #{pretty(old)}, yet still it lacks. " <>
        "Now it longs for #{pretty(new)}: #{reason}.",
      %{"beings" => [ctx.id]}
    )

    {"yearn",
     "#{String.capitalize(pretty(old))} was not it. I long for #{pretty(new)}, because #{reason}."}
  end
end
