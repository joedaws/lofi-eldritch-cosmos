defmodule Eldritch.Being.Actions.Anxiety do
  @moduledoc """
  Anxiety is not the lack of the object but the lack of lack: it arises
  when the objet a, the cause of desire, comes too close. A being
  holding too much of its objet a casts it away, back into the place it
  stands in, and its lack returns.
  """
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action
  alias Eldritch.Lacan

  @too_close 8

  @impl true
  def priority(), do: 9.5

  @impl true
  def preconditions_satisfied?(ctx) do
    Map.get(resources(ctx), psyche(ctx)["objet_a"], 0) >= @too_close
  end

  @impl true
  def perform(ctx) do
    a = psyche(ctx)["objet_a"]
    cast = Eldritch.Being.Actions.take_resource(ctx.pid, a, 1_000)

    case here(ctx) do
      %{"pid" => node_pid, "resource_type" => ^a} ->
        # what is cast away returns to the place it came from
        Cosmos.Entity.Server.update_component(node_pid, "reserve", fn comp ->
          %{comp | value: Map.update!(comp.value, "amount", &min(&1 + cast, comp.value["max"]))}
        end)

      _ ->
        :ok
    end

    Lacan.update(ctx.pid, fn p ->
      %{p | "lack" => min(100, p["lack"] + 10)}
      |> Map.put("objet_a_revealed", true)
      |> Lacan.strengthen("real", 0.02)
    end)

    if :rand.uniform() < 0.5 do
      Eldritch.Chronicle.record(
        :anxiety,
        "#{ctx.being["name"]} is seized by dread and casts away its #{cast} #{pretty(a)}.",
        %{"beings" => [ctx.id], "node" => ctx.being["at_node"]}
      )
    end

    {"anxiety", "Too close. The #{pretty(a)} fills me with dread; I cast it away."}
  end
end
