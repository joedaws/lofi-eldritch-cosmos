defmodule Cosmos.System.Server do
  @moduledoc """
  system module must define a function update_components/0
  """
  use GenServer, restart: :permanent
  require Logger

  # client
  def start_link([system_module, cycle_duration]) do
    Logger.info("Initializing system #{inspect(system_module)}")

    GenServer.start_link(__MODULE__, [system_module, cycle_duration],
      name: via_tuple(system_module)
    )
  end

  def on(system_module) do
    Logger
    GenServer.cast(via_tuple(system_module), :start)
  end

  def off(system_module) do
    GenServer.call(via_tuple(system_module), :stop)
  end

  # callbacks
  @impl true
  def init([system_module, cycle_duration]) do
    {:ok, {system_module, cycle_duration, :off}}
  end

  @impl true
  def handle_cast(:start, {system_module, cycle_duration, _}) do
    status = :on
    Process.send(self(), :cycle, [])
    {:noreply, {system_module, cycle_duration, status}}
  end

  @impl true
  def handle_call(:stop, _from, {system_module, cycle_duration, _}) do
    status = :off
    {:reply, system_module, {system_module, cycle_duration, status}}
  end

  @impl true
  def handle_info(:cycle, {system_module, cycle_duration, status}) do
    if status == :on do
      cycle(system_module, cycle_duration)
    end

    {:noreply, {system_module, cycle_duration, status}}
  end

  defp cycle(system_module, cycle_duration) do
    Logger.debug("#{inspect(system_module)} cycling")
    system_module.update_components(system_module)
    Process.send_after(self(), :cycle, cycle_duration)
  end

  defp via_tuple(system_module) do
    Cosmos.ProcessRegistry.via_tuple({__MODULE__, system_module})
  end
end
