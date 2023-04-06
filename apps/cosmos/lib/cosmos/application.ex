defmodule Cosmos.Application do
  use Application

  def start(_, _) do
    Cosmos.Supervisor.start_link()
  end
end
