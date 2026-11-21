defmodule Eldritch.System.Regrowth do
  @moduledoc """
  Nodes slowly replenish their reserves.
  """

  def update_components(system) do
    Registry.dispatch(Cosmos.SystemRegistry, system, fn entries ->
      for {pid, _} <- entries do
        GenServer.cast(pid, {:update_component, "reserve", &regrow/1})
      end
    end)
  end

  defp regrow(%{value: %{"amount" => amount, "max" => max}} = comp) do
    %{comp | value: %{comp.value | "amount" => min(max, amount + 1)}}
  end
end
