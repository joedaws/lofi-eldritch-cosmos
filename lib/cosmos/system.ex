defmodule Cosmos.System do
  require Logger

  @systems %{
    temporal_decay: Cosmos.System.TemporalDecay
  }

  def start_link do
    Logger.info("Starting systems")

    children = Enum.map(Map.values(@systems), &worker_spec/1)
    Logger.info("#{inspect(__MODULE__)} starting systems")
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def on(system_atom) do
    Map.get(@systems, system_atom).on()
  end

  def off(system_atom) do
    Map.get(@systems, system_atom).off()
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  defp worker_spec(system) do
    default_worker_spec = {system, []}
    Supervisor.child_spec(default_worker_spec, id: 1)
  end
end
