defmodule Dev.TemporalDecay do
  @moduledoc """
  Useful for testing or observing the temporal_decay system

  Creates a being and a node
  turns on the temporal_decay system
  """
  being_id = Eldritch.Being.Builder.build({:new, :being, :standard})

  Cosmos.System.on(Eldritch.System.TemporalDecay)
end
