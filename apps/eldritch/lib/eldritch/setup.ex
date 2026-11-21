defmodule Eldritch.Setup do
  @moduledoc """
  Start up script for the Eldritch application:

    1. registers every system with Cosmos
    2. loads the persisted cosmos (`config :eldritch, load_on_start: true`)
    3. starts the simulation (`config :eldritch, autostart: true` or
       the `ELDRITCH_AUTOSTART=true` environment variable)
  """
  require Logger

  def run() do
    Logger.info("initializing systems for Eldritch Application")
    Eldritch.Simulation.initialize_systems()

    if Application.get_env(:eldritch, :load_on_start, true) do
      Eldritch.Genesis.load_all()
    end

    if autostart?() do
      Eldritch.Simulation.start()
    end

    :ok
  end

  defp autostart?() do
    System.get_env("ELDRITCH_AUTOSTART") in ["1", "true"] or
      Application.get_env(:eldritch, :autostart, false)
  end
end
