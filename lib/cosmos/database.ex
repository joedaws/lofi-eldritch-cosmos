defmodule Cosmos.Database do
  use GenServer
  require Logger

  @num_workers 3

  def start do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def store(key, data) do
    GenServer.cast(__MODULE__, {:store, key, data})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def choose_worker(workers, key) do
    Map.get(workers, :erlang.phash2(key, @num_workers))
  end

  @impl true
  def init(_) do
    persist_dir = Cosmos.get_persist_dir()

    workers =
      for i <- 0..(@num_workers - 1),
          into: %{},
          do: {i, Cosmos.DatabaseWorker.start(persist_dir) |> elem(1)}

    Logger.info("#{inspect(__MODULE__)} started #{@num_workers} workers")

    {:ok, workers}
  end

  @impl true
  def handle_cast({:store, key, data}, workers) do
    worker = choose_worker(workers, key)

    Cosmos.DatabaseWorker.store(worker, key, data)

    {:noreply, workers}
  end

  @impl true
  def handle_call({:get, key}, _from, workers) do
    worker = choose_worker(workers, key)

    data =
      case Cosmos.DatabaseWorker.get(worker, key) do
        {:ok, contents} -> contents
        :enoent -> :enoent
        _ -> nil
      end

    {:reply, data, workers}
  end
end
