defmodule Cosmos.System do
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: via_tuple())
  end

  def add(system_module, cycle_duration) do
    GenServer.cast(via_tuple(), {:add, system_module, cycle_duration})
  end

  def remove(system_module) do
    GenServer.cast(via_tuple(), {:remove, system_module})
  end

  def on(system_module) do
    GenServer.cast(via_tuple(), {:on, system_module})
  end

  def off(system_module) do
    GenServer.cast(via_tuple(), {:off, system_module})
  end

  def valid_system?(system_module) do
    GenServer.call(via_tuple(), {:valid_system, system_module})
  end

  @doc """
  Change how often (ms) a cycling system runs
  """
  def set_cycle_duration(system_module, cycle_duration) do
    GenServer.cast(via_tuple(), {:set_cycle_duration, system_module, cycle_duration})
  end

  @doc """
  All initialized system atoms
  """
  def systems() do
    GenServer.call(via_tuple(), :systems)
  end

  @doc """
  Status (on/off, cycle duration, cycles run) of an initialized system
  """
  def status(system_module) do
    if valid_system?(system_module), do: Cosmos.System.Server.status(system_module), else: nil
  end

  # callbacks
  def init(_) do
    {:ok, MapSet.new()}
  end

  def handle_cast({:add, system_module, cycle_duration}, systems) when is_atom(system_module) do
    updated_systems =
      case MapSet.member?(systems, system_module) do
        true ->
          Logger.debug("System #{inspect(system_module)} already initialized")
          systems

        false ->
          Cosmos.System.Supervisor.initialize_system(system_module, cycle_duration)
          MapSet.put(systems, system_module)
      end

    {:noreply, updated_systems}
  end

  def handle_cast({:remove, system_module}, systems) when is_atom(system_module) do
    updated_systems =
      case MapSet.member?(systems, system_module) do
        true ->
          MapSet.delete(systems, system_module)

        false ->
          Logger.debug("System #{inspect(system_module)} not initialized")
          systems
      end

    {:noreply, updated_systems}
  end

  def handle_cast({:on, system_module}, systems) when is_atom(system_module) do
    case MapSet.member?(systems, system_module) do
      true ->
        Cosmos.System.Server.on(system_module)

      false ->
        Logger.debug(
          "System #{inspect(system_module)} can not be turned on since it hasn't been initialized"
        )
    end

    {:noreply, systems}
  end

  def handle_cast({:off, system_module}, systems) when is_atom(system_module) do
    case MapSet.member?(systems, system_module) do
      true ->
        Cosmos.System.Server.off(system_module)

      false ->
        Logger.debug(
          "System #{inspect(system_module)} can not be turned off since it hasn't been initialized"
        )
    end

    {:noreply, systems}
  end

  def handle_cast({:set_cycle_duration, system_module, cycle_duration}, systems) do
    if MapSet.member?(systems, system_module) do
      Cosmos.System.Server.set_cycle_duration(system_module, cycle_duration)
    end

    {:noreply, systems}
  end

  def handle_call(:systems, _from, systems) do
    {:reply, MapSet.to_list(systems), systems}
  end

  def handle_call({:valid_system, system_module}, _from, systems) do
    {:reply, MapSet.member?(systems, system_module), systems}
  end

  defp via_tuple() do
    Cosmos.ProcessRegistry.via_tuple(__MODULE__)
  end
end
