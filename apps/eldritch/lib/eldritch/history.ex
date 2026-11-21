defmodule Eldritch.History do
  @moduledoc """
  What has happened, kept on disk in `history.sqlite3` next to the cosmos:

    * **the chronicle** - every event of `Eldritch.Chronicle`, so the
      cosmos remembers its past across restarts. Events are indexed by the
      beings they involve. Events older than `config :eldritch,
      :chronicle_retention_ms` (30 days) are pruned on start.
    * **interactions** - what each person did with their being: every
      answer to an incantation (card, answer, right or wrong, box before and
      after), summoning, card edits, temperament changes and beckons. This
      is the person's own study record; unmaking the cosmos does not erase
      it. It is the basis for exporting to a person's learning agent.

  Owners are opaque ids (stored as text). Writes are appended in batches:
  they collect in memory and are committed in one transaction every
  #{500} ms; `sync/0` flushes immediately.
  """
  use GenServer
  require Logger

  @db_file "history.sqlite3"
  @flush_ms 500
  @day 24 * 60 * 60 * 1000

  # ---------- client ----------

  def start_link(_) do
    GenServer.start_link(__MODULE__, Cosmos.get_persist_dir(), name: __MODULE__)
  end

  @doc "Appends a chronicle event (as built by `Eldritch.Chronicle.record/3`)"
  def append_chronicle(event), do: GenServer.cast(__MODULE__, {:chronicle, event})

  @doc "Records something a person did. `data` is any JSON-friendly map."
  def record(owner, being_id, kind, data \\ %{}) when not is_nil(owner) do
    GenServer.cast(
      __MODULE__,
      {:interaction, to_string(owner), being_id, to_string(kind), data, now()}
    )
  end

  def sync(), do: GenServer.call(__MODULE__, :sync, 30_000)

  @doc "The most recent chronicle events, newest first"
  def recent_chronicle(limit \\ 300), do: GenServer.call(__MODULE__, {:recent_chronicle, limit})

  @doc "The highest chronicle sequence number on disk (0 if none)"
  def max_seq(), do: GenServer.call(__MODULE__, :max_seq)

  @doc "Chronicle events involving a being, newest first"
  def being_events(being_id, limit \\ 100),
    do: GenServer.call(__MODULE__, {:being_events, being_id, limit})

  @doc """
  A person's interactions, newest first. Options: `:limit` (default 100),
  `:before` (an interaction id, for paging).
  """
  def interactions(owner, opts \\ []),
    do: GenServer.call(__MODULE__, {:interactions, to_string(owner), opts})

  @doc """
  Everything about a person in time order: their interactions plus the
  chronicle events of every being they have owned or tended.
  """
  def export(owner), do: GenServer.call(__MODULE__, {:export, to_string(owner)}, 60_000)

  @doc "Forgets the chronicle (when the cosmos is unmade). Interactions stay."
  def clear_chronicle(), do: GenServer.call(__MODULE__, :clear_chronicle)

  @doc "Forgets all history (tests start from a clean slate with it)"
  def reset(), do: GenServer.call(__MODULE__, :reset)

  @doc """
  Forgets everything a person did. Must be called when an account is
  deleted, so a later account that reuses the id starts clean.
  """
  def forget(owner), do: GenServer.call(__MODULE__, {:forget, to_string(owner)})

  # ---------- server ----------

  @impl true
  def init(persist_dir) do
    Process.flag(:trap_exit, true)
    File.mkdir_p!(persist_dir)
    {:ok, conn} = Exqlite.Sqlite3.open(Path.join(persist_dir, @db_file))

    :ok =
      Exqlite.Sqlite3.execute(conn, """
      PRAGMA journal_mode = WAL;
      PRAGMA synchronous = NORMAL;
      CREATE TABLE IF NOT EXISTS chronicle (
        seq INTEGER PRIMARY KEY,
        at INTEGER NOT NULL,
        tick INTEGER,
        kind TEXT NOT NULL,
        text TEXT NOT NULL,
        node TEXT,
        beings TEXT NOT NULL DEFAULT '[]'
      );
      CREATE TABLE IF NOT EXISTS chronicle_beings (
        being_id TEXT NOT NULL,
        seq INTEGER NOT NULL,
        PRIMARY KEY (being_id, seq)
      );
      CREATE TABLE IF NOT EXISTS interactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner TEXT NOT NULL,
        being_id TEXT,
        at INTEGER NOT NULL,
        kind TEXT NOT NULL,
        data TEXT NOT NULL DEFAULT '{}'
      );
      CREATE INDEX IF NOT EXISTS interactions_owner ON interactions (owner, id);
      """)

    state = %{conn: conn, chronicle: [], interactions: [], timer: nil}
    prune(state)
    {:ok, state}
  end

  @impl true
  def handle_cast({:chronicle, event}, state) do
    {:noreply, schedule(%{state | chronicle: [event | state.chronicle]})}
  end

  def handle_cast({:interaction, _owner, _being, _kind, _data, _at} = row, state) do
    {:noreply, schedule(%{state | interactions: [row | state.interactions]})}
  end

  @impl true
  def handle_call(:sync, _from, state), do: {:reply, :ok, flush(state)}

  def handle_call({:recent_chronicle, limit}, _from, state) do
    state = flush(state)

    rows =
      select(
        state.conn,
        "SELECT seq, at, tick, kind, text, node, beings FROM chronicle ORDER BY seq DESC LIMIT ?1",
        [limit]
      )

    {:reply, Enum.map(rows, &chronicle_row/1), state}
  end

  def handle_call(:max_seq, _from, state) do
    state = flush(state)
    [[max]] = select(state.conn, "SELECT COALESCE(MAX(seq), 0) FROM chronicle", [])
    {:reply, max, state}
  end

  def handle_call({:being_events, being_id, limit}, _from, state) do
    state = flush(state)

    rows =
      select(
        state.conn,
        """
        SELECT c.seq, c.at, c.tick, c.kind, c.text, c.node, c.beings
        FROM chronicle_beings b JOIN chronicle c ON c.seq = b.seq
        WHERE b.being_id = ?1 ORDER BY c.seq DESC LIMIT ?2
        """,
        [being_id, limit]
      )

    {:reply, Enum.map(rows, &chronicle_row/1), state}
  end

  def handle_call({:interactions, owner, opts}, _from, state) do
    state = flush(state)
    limit = Keyword.get(opts, :limit, 100)
    before = Keyword.get(opts, :before) || 9_223_372_036_854_775_807

    rows =
      select(
        state.conn,
        "SELECT id, owner, being_id, at, kind, data FROM interactions WHERE owner = ?1 AND id < ?2 ORDER BY id DESC LIMIT ?3",
        [owner, before, limit]
      )

    {:reply, Enum.map(rows, &interaction_row/1), state}
  end

  def handle_call({:export, owner}, _from, state) do
    state = flush(state)

    interactions =
      state.conn
      |> select(
        "SELECT id, owner, being_id, at, kind, data FROM interactions WHERE owner = ?1 ORDER BY id",
        [owner]
      )
      |> Enum.map(&interaction_row/1)

    being_ids =
      interactions |> Enum.map(& &1["being_id"]) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    events =
      Enum.flat_map(being_ids, fn being_id ->
        state.conn
        |> select(
          """
          SELECT c.seq, c.at, c.tick, c.kind, c.text, c.node, c.beings
          FROM chronicle_beings b JOIN chronicle c ON c.seq = b.seq WHERE b.being_id = ?1
          """,
          [being_id]
        )
        |> Enum.map(&(chronicle_row(&1) |> Map.put("about_being", being_id)))
      end)
      |> Enum.uniq_by(& &1["seq"])

    records =
      Enum.map(interactions, &Map.put(&1, "type", "interaction")) ++
        Enum.map(events, &Map.put(&1, "type", "event"))

    {:reply, Enum.sort_by(records, &{&1["at"], &1["type"]}), state}
  end

  def handle_call(:clear_chronicle, _from, state) do
    state = flush(state)

    :ok =
      Exqlite.Sqlite3.execute(state.conn, "DELETE FROM chronicle; DELETE FROM chronicle_beings;")

    {:reply, :ok, state}
  end

  def handle_call(:reset, _from, state) do
    state = flush(state)

    :ok =
      Exqlite.Sqlite3.execute(
        state.conn,
        "DELETE FROM chronicle; DELETE FROM chronicle_beings; DELETE FROM interactions;"
      )

    {:reply, :ok, state}
  end

  def handle_call({:forget, owner}, _from, state) do
    state = flush(state)
    run(state.conn, "DELETE FROM interactions WHERE owner = ?1", [owner])
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:flush, state), do: {:noreply, flush(%{state | timer: nil})}

  @impl true
  def terminate(_reason, state) do
    flush(state)
    Exqlite.Sqlite3.close(state.conn)
  end

  # ---------- internals ----------

  defp schedule(%{timer: nil} = state),
    do: %{state | timer: Process.send_after(self(), :flush, @flush_ms)}

  defp schedule(state), do: state

  defp flush(%{chronicle: [], interactions: []} = state), do: state

  defp flush(state) do
    if state.timer, do: Process.cancel_timer(state.timer)

    try do
      :ok = Exqlite.Sqlite3.execute(state.conn, "BEGIN")

      for e <- Enum.reverse(state.chronicle) do
        beings = Map.get(e, "beings", [])

        run(
          state.conn,
          "INSERT OR REPLACE INTO chronicle (seq, at, tick, kind, text, node, beings) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
          [e["seq"], e["at"], e["tick"], e["kind"], e["text"], e["node"], Jason.encode!(beings)]
        )

        for b <- beings,
            do:
              run(
                state.conn,
                "INSERT OR IGNORE INTO chronicle_beings (being_id, seq) VALUES (?1, ?2)",
                [b, e["seq"]]
              )
      end

      for {:interaction, owner, being_id, kind, data, at} <- Enum.reverse(state.interactions) do
        run(
          state.conn,
          "INSERT INTO interactions (owner, being_id, at, kind, data) VALUES (?1, ?2, ?3, ?4, ?5)",
          [owner, being_id, at, kind, Jason.encode!(data)]
        )
      end

      :ok = Exqlite.Sqlite3.execute(state.conn, "COMMIT")
      %{state | chronicle: [], interactions: [], timer: nil}
    rescue
      error ->
        Exqlite.Sqlite3.execute(state.conn, "ROLLBACK")
        Logger.error("history flush failed, will retry: #{Exception.message(error)}")
        %{state | timer: Process.send_after(self(), :flush, @flush_ms)}
    end
  end

  defp prune(state) do
    cutoff = now() - Application.get_env(:eldritch, :chronicle_retention_ms, 30 * @day)

    run(
      state.conn,
      "DELETE FROM chronicle_beings WHERE seq IN (SELECT seq FROM chronicle WHERE at < ?1)",
      [cutoff]
    )

    run(state.conn, "DELETE FROM chronicle WHERE at < ?1", [cutoff])
  end

  defp chronicle_row([seq, at, tick, kind, text, node, beings]) do
    %{
      "seq" => seq,
      "at" => at,
      "tick" => tick,
      "kind" => kind,
      "text" => text,
      "node" => node,
      "beings" => Jason.decode!(beings)
    }
  end

  defp interaction_row([id, owner, being_id, at, kind, data]) do
    %{
      "id" => id,
      "owner" => owner,
      "being_id" => being_id,
      "at" => at,
      "kind" => kind,
      "data" => Jason.decode!(data)
    }
  end

  defp run(conn, sql, args) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, sql)
    :ok = Exqlite.Sqlite3.bind(stmt, args)
    :done = Exqlite.Sqlite3.step(conn, stmt)
    :ok = Exqlite.Sqlite3.release(conn, stmt)
  end

  defp select(conn, sql, args) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, sql)
    :ok = Exqlite.Sqlite3.bind(stmt, args)
    {:ok, rows} = Exqlite.Sqlite3.fetch_all(conn, stmt)
    :ok = Exqlite.Sqlite3.release(conn, stmt)
    rows
  end

  # wall-clock time: history is about when people did things
  defp now(), do: System.system_time(:millisecond)
end
