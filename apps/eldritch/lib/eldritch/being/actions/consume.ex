defmodule Eldritch.Being.Actions.Consume do
  @moduledoc """
  Need: a hungry being consumes what it carries. Its desired resource
  nourishes most. A being consumed by lack ignores its hunger until it
  is starving.
  """
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action

  @hunger 100
  @bite 3

  @impl true
  def priority(), do: 10

  # beyond the pleasure principle: when lack is overwhelming a being
  # neglects its need to chase its desire, until it is truly starving
  @overwhelming_lack 80
  @starving 25

  @impl true
  def preconditions_satisfied?(ctx) do
    ichor(ctx) < @hunger and map_size(resources(ctx)) > 0 and
      (ichor(ctx) < @starving or lack(ctx) < @overwhelming_lack)
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
