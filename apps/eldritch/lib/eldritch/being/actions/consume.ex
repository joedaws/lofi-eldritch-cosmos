defmodule Eldritch.Being.Actions.Consume do
  @moduledoc "A hungry being consumes what it carries. Its desired resource nourishes most."
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action

  @hunger 100
  @bite 3

  @impl true
  def priority(), do: 10

  @impl true
  def preconditions_satisfied?(ctx) do
    ichor(ctx) < @hunger and map_size(resources(ctx)) > 0
  end

  @impl true
  def perform(ctx) do
    resources = resources(ctx)
    desire = desire(ctx)

    food =
      if Map.get(resources, desire, 0) > 0,
        do: desire,
        else: resources |> Enum.max_by(&elem(&1, 1)) |> elem(0)

    eaten = Eldritch.Being.Actions.take_resource(ctx.pid, food, @bite)
    gain = eaten * if(food == desire, do: 6, else: 3)
    Eldritch.Being.Actions.change_ichor(ctx.pid, gain)

    flavour = if food == desire, do: " It is exquisite.", else: ""
    {"consume", "I consume #{eaten} #{pretty(food)} (+#{gain} ichor).#{flavour}"}
  end
end
