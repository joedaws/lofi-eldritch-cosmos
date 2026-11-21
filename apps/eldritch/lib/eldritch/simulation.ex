defmodule Eldritch.Simulation do
  @moduledoc """
  Starts, stops and paces every system of the Eldritch cosmos.

  Each cycling system runs every `multiplier * tick_ms` milliseconds.
  The remind system works in wall-clock time (spaced repetition is
  about *your* memory, not the beings'), so it is not scaled.
  """
  use GenServer
  require Logger

  @min_tick_ms 100
  @max_tick_ms 10_000

  # system => cycle multiplier (or {:fixed, ms})
  @systems [
    {Eldritch.System.Volition, 1},
    {Eldritch.System.Observation, 1},
    {Eldritch.System.TemporalDecay, 1},
    {Eldritch.System.Harvest, 2},
    {Eldritch.System.Communion, 2},
    {Eldritch.System.Regrowth, 4},
    {Eldritch.System.Remind, {:fixed, 1000}}
  ]

  @marker_systems [:is_being, :is_node, :is_carte, :inventory, :attribute]

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def systems(), do: Enum.map(@systems, &elem(&1, 0))

  @doc """
  Registers every Eldritch system with Cosmos (they start switched off)
  """
  def initialize_systems() do
    tick_ms = tick_ms()
    Enum.each(@marker_systems, &Cosmos.System.add(&1, :none))

    Enum.each(@systems, fn {system, multiplier} ->
      Cosmos.System.add(system, cycle_duration(multiplier, tick_ms))
    end)

    # a synchronous call guarantees the casts above have been processed
    Cosmos.System.systems()
  end

  def start(), do: GenServer.call(__MODULE__, :start)
  def stop(), do: GenServer.call(__MODULE__, :stop)
  def running?(), do: GenServer.call(__MODULE__, :running?)
  def tick_ms(), do: GenServer.call(__MODULE__, :tick_ms)
  def set_tick_ms(ms) when is_integer(ms), do: GenServer.call(__MODULE__, {:set_tick_ms, ms})

  @doc "Called by the volition system once per cycle"
  def tick(), do: GenServer.cast(__MODULE__, :tick)

  def tick_count() do
    case :ets.whereis(__MODULE__) do
      :undefined -> 0
      _ -> :ets.lookup_element(__MODULE__, :tick, 2)
    end
  end

  def status() do
    GenServer.call(__MODULE__, :status)
  end

  # callbacks

  @impl true
  def init(:ok) do
    :ets.new(__MODULE__, [:named_table, :public, read_concurrency: true])
    :ets.insert(__MODULE__, {:tick, 0})

    tick_ms = Application.get_env(:eldritch, :tick_ms, 1000) |> clamp()
    {:ok, %{running: false, tick_ms: tick_ms, started_at: nil}}
  end

  @impl true
  def handle_call(:start, _from, state) do
    apply_cycle_durations(state.tick_ms)
    Enum.each(systems(), &Cosmos.System.on/1)
    Logger.info("the cosmos stirs: simulation started (tick #{state.tick_ms}ms)")

    unless state.running do
      Eldritch.Chronicle.record(:cosmos, "The cosmos stirs.")
    end

    {:reply, :ok, %{state | running: true, started_at: state.started_at || now()}}
  end

  def handle_call(:stop, _from, state) do
    Enum.each(systems(), &Cosmos.System.off/1)
    Logger.info("the cosmos slumbers: simulation stopped")

    if state.running do
      Eldritch.Chronicle.record(:cosmos, "The cosmos slumbers.")
    end

    {:reply, :ok, %{state | running: false}}
  end

  def handle_call(:running?, _from, state), do: {:reply, state.running, state}
  def handle_call(:tick_ms, _from, state), do: {:reply, state.tick_ms, state}

  def handle_call({:set_tick_ms, ms}, _from, state) do
    tick_ms = clamp(ms)
    apply_cycle_durations(tick_ms)
    {:reply, tick_ms, %{state | tick_ms: tick_ms}}
  end

  def handle_call(:status, _from, state) do
    {:reply,
     %{
       "running" => state.running,
       "tick_ms" => state.tick_ms,
       "tick" => tick_count(),
       "min_tick_ms" => @min_tick_ms,
       "max_tick_ms" => @max_tick_ms
     }, state}
  end

  @impl true
  def handle_cast(:tick, state) do
    :ets.update_counter(__MODULE__, :tick, 1)
    {:noreply, state}
  end

  defp apply_cycle_durations(tick_ms) do
    Enum.each(@systems, fn {system, multiplier} ->
      Cosmos.System.set_cycle_duration(system, cycle_duration(multiplier, tick_ms))
    end)
  end

  defp cycle_duration({:fixed, ms}, _tick_ms), do: ms
  defp cycle_duration(multiplier, tick_ms), do: multiplier * tick_ms

  defp clamp(ms), do: ms |> max(@min_tick_ms) |> min(@max_tick_ms)

  defp now(), do: System.system_time(:millisecond)
end
