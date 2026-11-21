defmodule Cosmos.Database do
  @moduledoc """
  SQLite backed persistence for entities, with write-behind batching.

  Entity servers save their entity after every change, which can be
  thousands of times per second in a busy cosmos. Instead of hitting the
  disk each time, `store/2` and `delete/1` only record the latest version
  of each entity in memory ("dirty" entries). Every `flush_interval_ms`
  (default #{500}) — or as soon as #{5_000} entities are dirty — all
  pending changes are written in a single transaction.

    * A burst of updates to one entity costs one row write per flush.
    * `get/1` reads its own pending writes, so callers never see stale data.
    * `sync/0` flushes immediately (used before shutdown, after seeding, in tests).
    * On a crash, at most one flush interval of changes is lost.

  The database is `cosmos.sqlite3` in the user data directory
  (`Cosmos.get_persist_dir/0`), with one row per entity:

      entities(id TEXT PRIMARY KEY, kind TEXT, data BLOB, updated_at INTEGER)

  `data` is the `:erlang.term_to_binary/1` encoded entity. `kind` comes from
  the entity's marker component (`is_being` → "being", `is_node` → "node", ...)
  so kinds can be queried without decoding every entity.

  Entities saved by the earlier one-file-per-entity store are imported on
  start up and the old files are moved to `legacy-files-backup/`.
  """
  use GenServer
  require Logger

  @db_file "cosmos.sqlite3"
  @default_flush_interval_ms 500
  @max_dirty 5_000

  # client

  def start_link(_) do
    GenServer.start_link(__MODULE__, Cosmos.get_persist_dir(), name: __MODULE__)
  end

  def store(key, data), do: GenServer.cast(__MODULE__, {:store, to_string(key), data})

  def get(key), do: GenServer.call(__MODULE__, {:get, to_string(key)})

  def delete(key), do: GenServer.cast(__MODULE__, {:delete, to_string(key)})

  @doc "Writes every pending change to disk now"
  def sync(), do: GenServer.call(__MODULE__, :sync, 60_000)

  @doc "Removes every entity"
  def delete_all(), do: GenServer.call(__MODULE__, :delete_all, 60_000)

  @doc "Number of stored entities"
  def count(), do: GenServer.call(__MODULE__, :count)

  @doc "Path of the SQLite database file"
  def path(), do: Path.join(Cosmos.get_persist_dir(), @db_file)

  @doc """
  Supported filters:
    * `"entities"` - `%{"entity_ids" => [...]}`
    * `"beings"`   - `%{"being_ids" => [...]}`
  """
  def query(filter), do: GenServer.call(__MODULE__, {:query, filter}, 60_000)

  # server

  @impl true
  def init(persist_dir) do
    Process.flag(:trap_exit, true)
    File.mkdir_p!(persist_dir)
    db_path = Path.join(persist_dir, @db_file)
    Logger.info("Opening cosmos database #{db_path}")

    {:ok, conn} = Exqlite.Sqlite3.open(db_path)

    :ok =
      Exqlite.Sqlite3.execute(conn, """
      PRAGMA journal_mode = WAL;
      PRAGMA synchronous = NORMAL;
      CREATE TABLE IF NOT EXISTS entities (
        id TEXT PRIMARY KEY,
        kind TEXT,
        data BLOB NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS entities_kind ON entities (kind);
      """)

    {:ok, upsert} =
      Exqlite.Sqlite3.prepare(conn, """
      INSERT INTO entities (id, kind, data, updated_at) VALUES (?1, ?2, ?3, ?4)
      ON CONFLICT (id) DO UPDATE SET
        kind = excluded.kind, data = excluded.data, updated_at = excluded.updated_at
      """)

    {:ok, remove} = Exqlite.Sqlite3.prepare(conn, "DELETE FROM entities WHERE id = ?1")
    {:ok, select} = Exqlite.Sqlite3.prepare(conn, "SELECT data FROM entities WHERE id = ?1")

    state = %{
      conn: conn,
      stmts: %{upsert: upsert, remove: remove, select: select},
      dirty: %{},
      timer: nil,
      flush_interval:
        Application.get_env(:cosmos, :flush_interval_ms, @default_flush_interval_ms)
    }

    state = import_legacy_files(state, persist_dir)
    {:ok, state}
  end

  @impl true
  def handle_cast({:store, key, data}, state) do
    {:noreply, mark_dirty(state, key, {:put, data})}
  end

  def handle_cast({:delete, key}, state) do
    {:noreply, mark_dirty(state, key, :delete)}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    data =
      case Map.get(state.dirty, key) do
        {:put, data} -> data
        :delete -> nil
        nil -> read(state, key)
      end

    {:reply, data, state}
  end

  def handle_call(:sync, _from, state), do: {:reply, :ok, flush(state)}

  def handle_call(:delete_all, _from, state) do
    :ok = Exqlite.Sqlite3.execute(state.conn, "DELETE FROM entities")
    {:reply, :ok, %{state | dirty: %{}}}
  end

  def handle_call(:count, _from, state) do
    state = flush(state)
    [[count]] = select_all(state.conn, "SELECT count(*) FROM entities")
    {:reply, count, state}
  end

  def handle_call({:query, filter}, _from, state) do
    # pending writes first so the answer includes them
    state = flush(state)

    result =
      case filter do
        "entities" ->
          %{"entity_ids" => state.conn |> select_all("SELECT id FROM entities") |> ids()}

        "beings" ->
          ids =
            state.conn
            |> select_all("SELECT id FROM entities WHERE kind = 'being'")
            |> ids()

          %{"being_ids" => ids}

        _ ->
          %{}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_info(:flush, state), do: {:noreply, flush(%{state | timer: nil})}

  @impl true
  def terminate(_reason, state) do
    flush(state)
    Exqlite.Sqlite3.close(state.conn)
  end

  # internals

  defp mark_dirty(state, key, change) do
    state = %{state | dirty: Map.put(state.dirty, key, change)}

    cond do
      map_size(state.dirty) >= @max_dirty -> flush(state)
      state.timer == nil -> %{state | timer: Process.send_after(self(), :flush, state.flush_interval)}
      true -> state
    end
  end

  defp flush(%{dirty: dirty} = state) when map_size(dirty) == 0, do: state

  defp flush(state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    now = System.system_time(:millisecond)
    %{upsert: upsert, remove: remove} = state.stmts

    try do
      :ok = Exqlite.Sqlite3.execute(state.conn, "BEGIN")

      Enum.each(state.dirty, fn
        {key, {:put, data}} ->
          run(state.conn, upsert, [key, kind(data), {:blob, :erlang.term_to_binary(data)}, now])

        {key, :delete} ->
          run(state.conn, remove, [key])
      end)

      :ok = Exqlite.Sqlite3.execute(state.conn, "COMMIT")
      %{state | dirty: %{}, timer: nil}
    rescue
      error ->
        Exqlite.Sqlite3.execute(state.conn, "ROLLBACK")
        Logger.error("cosmos database flush failed, will retry: #{Exception.message(error)}")
        %{state | timer: Process.send_after(self(), :flush, state.flush_interval)}
    end
  end

  defp run(conn, stmt, args) do
    :ok = Exqlite.Sqlite3.bind(stmt, args)
    :done = Exqlite.Sqlite3.step(conn, stmt)
    :ok = Exqlite.Sqlite3.reset(stmt)
  end

  defp read(state, key) do
    %{select: select} = state.stmts
    :ok = Exqlite.Sqlite3.bind(select, [key])

    result =
      case Exqlite.Sqlite3.step(state.conn, select) do
        {:row, [data]} -> decode(data, key)
        :done -> nil
      end

    :ok = Exqlite.Sqlite3.reset(select)
    result
  end

  defp select_all(conn, sql) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, sql)
    {:ok, rows} = Exqlite.Sqlite3.fetch_all(conn, stmt)
    :ok = Exqlite.Sqlite3.release(conn, stmt)
    rows
  end

  defp ids(rows), do: Enum.map(rows, fn [id] -> id end)

  defp decode(binary, key) do
    :erlang.binary_to_term(binary)
  rescue
    ArgumentError ->
      Logger.warning("ignoring undecodable entity #{key}")
      nil
  end

  # the entity's marker component (e.g. "is_being") names its kind
  defp kind(%Cosmos.Entity{} = entity) do
    marker =
      entity
      |> Cosmos.Entity.components()
      |> Enum.find_value(fn
        %{name: "is_" <> kind} -> kind
        _ -> nil
      end)

    cond do
      marker -> marker
      # beings saved before the is_being marker existed
      Cosmos.Entity.component(entity, "ichor") != nil -> "being"
      true -> nil
    end
  end

  defp kind(_), do: nil

  # entities used to be stored as one term_to_binary file per entity, named by
  # the entity id. Only files that decode to an entity are imported and moved:
  # anything else in the data dir (other databases, notes) is left untouched.
  defp import_legacy_files(state, persist_dir) do
    legacy =
      persist_dir
      |> Path.join("*")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.reject(&String.contains?(Path.basename(&1), "."))
      |> Enum.flat_map(fn file ->
        with {:ok, binary} <- File.read(file),
             %Cosmos.Entity{} = entity <- safe_decode(binary) do
          [{file, entity}]
        else
          _ -> []
        end
      end)

    if legacy == [] do
      state
    else
      backup = Path.join(persist_dir, "legacy-files-backup")
      File.mkdir_p!(backup)

      state =
        Enum.reduce(legacy, state, fn {file, entity}, state ->
          key = Path.basename(file)
          File.rename!(file, Path.join(backup, key))
          %{state | dirty: Map.put(state.dirty, key, {:put, entity})}
        end)

      Logger.info("imported #{length(legacy)} legacy entity files (originals in #{backup})")
      flush(state)
    end
  end

  defp safe_decode(binary) do
    :erlang.binary_to_term(binary, [:safe])
  rescue
    ArgumentError -> nil
  end
end
