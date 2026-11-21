defmodule Eldritch.Application do
  use Application
  require Logger

  def start(_, _) do
    Logger.info("starting up eldritch")
    Eldritch.Supervisor.start_link()
  end
end
