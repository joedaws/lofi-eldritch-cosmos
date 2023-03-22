defmodule Cosmos.System.Scheduler do
  use Quantum, otp_app: :cosmos
  import Crontab.CronExpression
  require Logger

  def start_system(system_atom) when is_atom(system_atom) do
    __MODULE__.new_job()
    |> Quantum.Job.set_name(system_atom)
    |> Quantum.Job.set_schedule(~e[3]e)
    |> Quantum.Job.set_task(fn ->
      Logger.info("hello from #{system_atom} system")
    end)
    |> __MODULE__.add_job()
  end

  def stop_system(system_atom) when is_atom(system_atom) do
    __MODULE__.delete_job(system_atom)
  end
end
