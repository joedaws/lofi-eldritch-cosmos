defmodule Eldritch.System.TemporalDecay do
  @moduledoc """
  Time wears on every being: its ichor drains a little each cycle
  (never below zero). The volition system fades beings whose ichor
  has run dry.
  """
  require Logger
  @decay_amount %{"ichor" => 1}

  def update_components(system) do
    Registry.dispatch(Cosmos.SystemRegistry, system, fn entries ->
      for {pid, _} <- entries,
          do: GenServer.cast(pid, {:update_component, system, fn comp -> decrement(comp) end})
    end)
  end

  defp decrement(comp) do
    %{comp | value: max(0, comp.value - Map.get(@decay_amount, comp.name, 0))}
  end
end
