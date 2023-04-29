defmodule Eldritch.Application do
  use Application
  require Logger

  def start(_, _) do
    Logger.info("starting up eldritch")
    # run setup code
    Eldritch.Setup.start_link()

    Eldritch.Supervisor.start_link()
  end
end
