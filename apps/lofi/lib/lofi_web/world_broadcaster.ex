defmodule LofiWeb.WorldBroadcaster do
  @moduledoc """
  Builds the world once per tick and broadcasts it to every open page, so
  the cost of watching does not grow with the number of watchers (pages
  used to each ask for the whole world every second).

  It only works while someone watches. Each broadcast carries the chronicle
  events since the previous one; pages drop events they already have.
  """
  use GenServer

  # not "world": Phoenix already subscribes each channel to its own topic,
  # and sharing the name would deliver every snapshot twice
  @topic "cosmos:snapshots"
  @min_interval 500
  @max_interval 1000

  def topic(), do: @topic

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Registers a watching process (a channel); it is forgotten when it exits"
  def watch(pid), do: GenServer.cast(__MODULE__, {:watch, pid})

  def watchers(), do: GenServer.call(__MODULE__, :watchers)

  @impl true
  def init(:ok) do
    schedule()
    {:ok, %{watchers: MapSet.new(), last_seq: 0}}
  end

  @impl true
  def handle_cast({:watch, pid}, state) do
    Process.monitor(pid)
    {:noreply, %{state | watchers: MapSet.put(state.watchers, pid)}}
  end

  @impl true
  def handle_call(:watchers, _from, state), do: {:reply, MapSet.size(state.watchers), state}

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | watchers: MapSet.delete(state.watchers, pid)}}
  end

  def handle_info(:broadcast, state) do
    state = if MapSet.size(state.watchers) > 0, do: broadcast(state), else: state
    schedule()
    {:noreply, state}
  end

  # a failed tick (say, the database busy) is skipped; the next one tries again
  defp broadcast(state) do
    world =
      [since: state.last_seq, viewer: nil]
      |> Eldritch.World.snapshot()
      |> LofiWeb.WorldView.name_owners()

    Phoenix.PubSub.broadcast(Lofi.PubSub, @topic, {:world, world})

    case world["events"] do
      [%{"seq" => seq} | _] -> %{state | last_seq: seq}
      _ -> state
    end
  rescue
    error ->
      require Logger
      Logger.warning("world broadcast skipped: #{Exception.message(error)}")
      state
  catch
    :exit, reason ->
      require Logger
      Logger.warning("world broadcast skipped: #{inspect(reason)}")
      state
  end

  defp schedule() do
    interval =
      try do
        Eldritch.Simulation.tick_ms() |> max(@min_interval) |> min(@max_interval)
      catch
        :exit, _ -> @max_interval
      end

    Process.send_after(self(), :broadcast, interval)
  end
end
