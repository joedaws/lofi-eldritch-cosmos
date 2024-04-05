defmodule Eldritch.Setup do
  require Logger

  def start_link do
    Task.start_link(&init/0)
  end

  defp init() do
    initialize_systems()
  end

  defp initialize_systems() do
    Logger.info("initializing systems for Eldritch Application")
    # TODO make the cycle durations dependent on the Mix.env
    Cosmos.System.add(Eldritch.System.TemporalDecay, 20 * 1000)
    Cosmos.System.add(Eldritch.System.Harvest, 20 * 1000)
    Cosmos.System.add(:is_being, :none)
    Cosmos.System.add(:is_node, :none)
    Cosmos.System.add(:is_carte, :none)
    Cosmos.System.add(:inventory, :none)
    Cosmos.System.add(:attribute, :none)
    # make slightly shorter than Harvest
    Cosmos.System.add(Eldritch.System.Observation, 19 * 1000)
    # Need to make remind system configurable
    Cosmos.System.add(Eldritch.System.Remind, 3 * 1000)
  end
end
