defmodule Cosmos.System.Supervisor do
  require Logger

  def start_link() do
    Logger.info("Starting System Supervisor")
    DynamicSupervisor.start_link(name: __MODULE__, strategy: :one_for_one)
  end

  def child_spec(_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  def initialize_system(system_module, cycle_duration) do
    case start_child(system_module, cycle_duration) do
      {:ok, _} -> system_module
      {:error, {:already_started, _}} -> system_module
    end
  end

  defp start_child(system_module, cycle_duration) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Cosmos.System.Server, [system_module, cycle_duration]}
    )
  end
end
