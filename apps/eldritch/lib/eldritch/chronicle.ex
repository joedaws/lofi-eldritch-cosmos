defmodule Eldritch.Chronicle do
  @moduledoc """
  A bounded, in-memory log of noteworthy happenings in the cosmos
  (meetings, gifts, summonings, fadings, whispered incantations ...).
  """
  use Agent

  @max_events 300

  def start_link(_) do
    Agent.start_link(fn -> %{seq: 0, events: []} end, name: __MODULE__)
  end

  @doc """
  Record an event. `kind` is an atom, `text` a human readable line and
  `meta` an optional map (e.g. `%{"beings" => [...], "node" => id}`).
  """
  def record(kind, text, meta \\ %{}) do
    Agent.cast(__MODULE__, fn %{seq: seq, events: events} ->
      event =
        Map.merge(meta, %{
          "seq" => seq + 1,
          "kind" => Atom.to_string(kind),
          "text" => text,
          "at" => System.system_time(:millisecond),
          "tick" => Eldritch.Simulation.tick_count()
        })

      %{seq: seq + 1, events: Enum.take([event | events], @max_events)}
    end)
  end

  @doc "Most recent events first"
  def recent(limit \\ 50) do
    Agent.get(__MODULE__, fn %{events: events} -> Enum.take(events, limit) end)
  end

  @doc "Events with a sequence number greater than `seq`, most recent first"
  def since(seq, limit \\ 100) do
    Agent.get(__MODULE__, fn %{events: events} ->
      events |> Enum.take_while(&(&1["seq"] > seq)) |> Enum.take(limit)
    end)
  end

  def clear() do
    Agent.update(__MODULE__, fn state -> %{state | events: []} end)
  end
end
