defmodule Cosmos.System.TemporalDecay do
  @system_atom :temporal_decay

  def ichor do
    Registry.dispatch(Cosmos.SystemRegistry, @system_atom, fn entries ->
      for {pid, _} <- entries,
          do: send(pid, {:update_component, "ichor", fn x -> decrease_ichor(x) end})
    end)
  end

  defp decrease_ichor(old_ichor) do
    old_ichor - 1
  end
end
