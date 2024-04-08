defmodule Cosmos.Application do
  require Logger
  use Application

  def start(_, _) do
    Application.put_env(:cosmos, :local_db_dir, get_temp_dir())
    Cosmos.Supervisor.start_link()
  end

  defp get_temp_dir() do
    dir = Path.join(System.tmp_dir!(), "cosmos")
    Logger.info("Cosmos application will use #{dir} for local db dir")
    dir
  end
end
