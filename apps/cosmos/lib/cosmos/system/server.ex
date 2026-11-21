defmodule Cosmos.System.Server do
  @moduledoc """
  Drives a single system. Every `cycle_duration` milliseconds while the
  system is on, `system_module.update_components(system_module)` is called.

  The system module must define `update_components/1`. Marker systems
  (e.g. `:attribute`) have a cycle duration of `:none` and never cycle.
  """
  use GenServer, restart: :permanent
  require Logger

  # client
  def start_link([system_module, cycle_duration]) do
    Logger.debug("Initializing system #{inspect(system_module)}")

    GenServer.start_link(__MODULE__, [system_module, cycle_duration],
      name: via_tuple(system_module)
    )
  end

  def on(system_module) do
    GenServer.cast(via_tuple(system_module), :start)
  end

  def off(system_module) do
    GenServer.cast(via_tuple(system_module), :stop)
  end

  def set_cycle_duration(system_module, cycle_duration) do
    GenServer.cast(via_tuple(system_module), {:set_cycle_duration, cycle_duration})
  end

  def status(system_module) do
    GenServer.call(via_tuple(system_module), :status)
  end

  # callbacks
  @impl true
  def init([system_module, cycle_duration]) do
    {:ok,
     %{
       system: system_module,
       cycle_duration: cycle_duration,
       status: :off,
       # increases every time the system is turned on so stale :cycle
       # messages from an earlier "on" period are ignored
       generation: 0,
       cycles: 0
     }}
  end

  @impl true
  def handle_cast(:start, %{status: :on} = state), do: {:noreply, state}

  def handle_cast(:start, state) do
    state = %{state | status: :on, generation: state.generation + 1}

    if is_integer(state.cycle_duration) do
      send(self(), {:cycle, state.generation})
    end

    {:noreply, state}
  end

  def handle_cast(:stop, state) do
    {:noreply, %{state | status: :off}}
  end

  def handle_cast({:set_cycle_duration, cycle_duration}, state) do
    {:noreply, %{state | cycle_duration: cycle_duration}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, [:system, :cycle_duration, :status, :cycles]), state}
  end

  @impl true
  def handle_info({:cycle, generation}, %{status: :on, generation: generation} = state) do
    run_cycle(state.system)

    if is_integer(state.cycle_duration) do
      Process.send_after(self(), {:cycle, generation}, state.cycle_duration)
    end

    {:noreply, %{state | cycles: state.cycles + 1}}
  end

  def handle_info({:cycle, _stale_generation}, state), do: {:noreply, state}

  defp run_cycle(system_module) do
    Logger.debug("#{inspect(system_module)} cycling")

    try do
      system_module.update_components(system_module)
    catch
      kind, reason ->
        Logger.error(
          "system #{inspect(system_module)} cycle failed: " <>
            Exception.format(kind, reason, __STACKTRACE__)
        )
    end
  end

  defp via_tuple(system_module) do
    Cosmos.ProcessRegistry.via_tuple({__MODULE__, system_module})
  end
end
