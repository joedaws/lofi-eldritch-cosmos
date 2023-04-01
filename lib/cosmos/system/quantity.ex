defmodule Cosmos.System.Quantity do
  require Logger
  use GenServer
  @system_atom :Quantity
  # length of time in milliseconds
  @cycle_duration 300 * 1000

  # client
  def start_link(init_args) do
    Logger.info("Starting #{inspect(__MODULE__)}")
    GenServer.start_link(__MODULE__, init_args, name: via_tuple(@system_atom))
  end

  def on() do
    GenServer.cast(via_tuple(@system_atom), :start)
  end

  def off() do
    GenServer.call(via_tuple(@system_atom), :stop)
  end

  # callbacks
  @impl true
  def init([]) do
    {:ok, {@cycle_duration, :off}}
  end

  @impl true
  def init([cycle_duration]) do
    {:ok, {cycle_duration, :off}}
  end

  @impl true
  def handle_cast(:start, {cycle_duration, _}) do
    Process.send(self(), :cycle, [])
    status = :on
    {:noreply, {cycle_duration, status}}
  end

  @impl true
  def handle_call(:stop, _from, {cycle_duration, _}) do
    status = :off
    {:reply, @system_atom, {cycle_duration, status}}
  end

  @impl true
  def handle_info(:cycle, {cycle_duration, status}) do
    if status == :on do
      cycle(cycle_duration)
    end

    {:noreply, {cycle_duration, status}}
  end

  defp cycle(cycle_duration) do
    Logger.info("#{inspect(__MODULE__)} cycling")
    update_components()
    Process.send_after(self(), :cycle, cycle_duration)
  end

  defp update_components do
    Logger.info("quantity system has nothing to update")
  end

  defp via_tuple(system_atom) do
    Cosmos.ProcessRegistry.via_tuple({__MODULE__, system_atom})
  end
end
