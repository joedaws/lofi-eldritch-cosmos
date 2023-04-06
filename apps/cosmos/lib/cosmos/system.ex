defmodule Cosmos.System do
  require Logger

  @systems %{
    temporal_decay: Cosmos.System.TemporalDecay,
    attribute: Cosmos.System.Attribute,
    quantity: Cosmos.System.Quantity
  }

  def start_link do
    Logger.info("Starting systems")

    children = Enum.map(Map.values(@systems), &worker_spec/1)
    Logger.info("#{inspect(__MODULE__)} starting systems")
    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
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

  @doc """
  Raises an error if the given system atom is not a known one
  """
  def validate_system!(system) when is_atom(system) do
    case system in Map.keys(@systems) do
      true ->
        {:ok, system}

      false ->
        :error
    end
  end

  defp worker_spec(system) do
    default_worker_spec = {system, []}
    Supervisor.child_spec(default_worker_spec, id: {system, 1})
  end
end
