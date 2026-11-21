defmodule Cosmos.Entity.Cache do
  require Logger

  def start_link() do
    Logger.info("Started the entity cache")
    DynamicSupervisor.start_link(name: __MODULE__, strategy: :one_for_one)
  end

  def child_spec(_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  @doc """
  Returns the pid of the entity server for `entity_id`, starting it
  (and loading the entity from the database) if needed.
  """
  def server_process(entity_id) do
    case start_child(entity_id) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  @doc """
  Returns the pid of an already running entity server or nil.
  Unlike `server_process/1` this never starts a new server.
  """
  def lookup(entity_id) do
    case Registry.lookup(Cosmos.ProcessRegistry, {Cosmos.Entity.Server, entity_id}) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc """
  Returns the pid of the entity server if the entity is running or
  persisted, otherwise nil. Use this for ids coming from the outside
  world so unknown ids do not spawn empty phantom entities.
  """
  def existing_server_process(entity_id) when is_binary(entity_id) do
    cond do
      pid = lookup(entity_id) -> pid
      Cosmos.Database.get(entity_id) != nil -> server_process(entity_id)
      true -> nil
    end
  end

  def existing_server_process(_), do: nil

  @doc """
  Pids of every running entity server
  """
  def all_server_processes() do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.flat_map(fn
      {_, pid, _, _} when is_pid(pid) -> [pid]
      _ -> []
    end)
  end

  @doc """
  Stops the entity server (the persisted data is untouched).
  """
  def stop(entity_id) do
    case lookup(entity_id) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  defp start_child(entity_id) do
    DynamicSupervisor.start_child(__MODULE__, {Cosmos.Entity.Server, entity_id})
  end
end
