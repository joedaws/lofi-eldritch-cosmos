defmodule Eldritch.Clock do
  @moduledoc """
  Wall clock used for spaced repetition. Normally the system time; the
  replay recorder advances it artificially so a long stretch of
  cosmic time can be simulated in a few seconds.
  """

  @key {__MODULE__, :offset}

  def now_ms(), do: System.system_time(:millisecond) + :persistent_term.get(@key, 0)

  @doc "Moves the clock forward by `ms` milliseconds"
  def advance(ms), do: :persistent_term.put(@key, :persistent_term.get(@key, 0) + ms)

  def reset(), do: :persistent_term.erase(@key)
end
