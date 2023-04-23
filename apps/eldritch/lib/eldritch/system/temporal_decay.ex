defmodule Eldritch.System.TemporalDecay do
  require Logger
  @decay_amount %{"ichor" => 1}

  def update_components(system) do
    Registry.dispatch(Cosmos.SystemRegistry, system, fn entries ->
      for {pid, _} <- entries,
          do: GenServer.cast(pid, {:update_component, system, fn comp -> decrement(comp) end})
    end)
  end

  defp decrement(comp) do
    %{comp | value: comp.value - Map.get(@decay_amount, comp.name)}
  end
end
