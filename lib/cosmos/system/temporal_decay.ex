defmodule Cosmos.System.TemporalDecay do
  require Logger
  use GenServer
  @system_atom :temporal_decay
  # length of time in milliseconds
  @cycle_duration 3 * 1000
  @decay_amount %{"ichor" => 1}

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
    status = :on
    Process.send(self(), :cycle, [])
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
    Registry.dispatch(Cosmos.SystemRegistry, @system_atom, fn entries ->
      for {pid, _} <- entries,
          do: send(pid, {:update_component, @system_atom, fn comp -> decrement(comp) end})
    end)
  end

  defp decrement(comp) do
    %{comp | value: comp.value - Map.get(@decay_amount, comp.name)}
  end

  defp via_tuple(system_atom) do
    Cosmos.ProcessRegistry.via_tuple({__MODULE__, system_atom})
  end
end
