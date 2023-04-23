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
    Cosmos.System.add(Eldritch.System.TemporalDecay, 3 * 1000)
    Cosmos.System.add(:is_being, :none)
    Cosmos.System.add(:inventory, :none)
    Cosmos.System.add(:attribute, :none)
  end
end
