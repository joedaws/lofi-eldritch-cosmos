defmodule Mix.Tasks.Cosmos.Replay do
  use Mix.Task

  @shortdoc "Records a replay of the simulation and builds the static demo site in docs/"

  @moduledoc """
  Runs a fresh cosmos offline, tick by tick, records what happens and
  writes a static site that plays it back (for GitHub Pages):

      mix cosmos.replay [--ticks 1200] [--every 2] [--beings 14] [--rings 6,10,14] [--seed 7] [--out docs]

  Output: `<out>/index.html` (the visualization in replay mode),
  `<out>/replay.json` and `<out>/.nojekyll`.

  The recording uses its own data directory, so your cosmos is untouched.
  One tick stands for one second of spaced repetition time, and a
  simulated player answers some of the whispered incantations (mostly
  correctly) so recalls and revivals appear in the replay.
  """

  @switches [
    ticks: :integer,
    every: :integer,
    beings: :integer,
    rings: :string,
    seed: :integer,
    out: :string
  ]

  # one tick is one second of incantation time
  @tick_clock_ms 1000
  @answer_chance 0.08
  @correct_chance 0.75
  # bonds change constantly; recording them every few frames is plenty
  @bond_every 5

  alias Eldritch.{Entities, System}

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    ticks = opts[:ticks] || 1200
    every = max(1, opts[:every] || 2)
    out = opts[:out] || "docs"
    seed = opts[:seed] || 7

    # keep the recording away from the real cosmos and the real server
    Mix.Task.run("app.config")
    Application.put_env(:cosmos, :data_dir_name, "lofi-eldritch-cosmos-replay")
    Application.put_env(:eldritch, :load_on_start, false)
    Application.put_env(:eldritch, :autostart, false)
    # a recording is minutes long: give the commons minutes of life, not days,
    # so generations still rise and fall in the replay
    Application.put_env(:eldritch, :lifespan_ms, {500_000, 900_000})
    endpoint = Application.get_env(:lofi, LofiWeb.Endpoint, [])
    Application.put_env(:lofi, LofiWeb.Endpoint, Keyword.put(endpoint, :server, false))
    Logger.configure(level: :warning)
    Mix.Task.run("app.start")

    :rand.seed(:exsss, {seed, seed * 31, seed * 97})
    Eldritch.Simulation.initialize_systems()
    Eldritch.Genesis.reset()
    Eldritch.Clock.reset()

    rings =
      case opts[:rings] do
        nil -> [6, 10, 14]
        r -> r |> String.split(",", trim: true) |> Enum.map(&String.to_integer(String.trim(&1)))
      end

    Eldritch.Genesis.seed(beings: opts[:beings] || 14, rings: rings)

    graph = Entities.node_map()
    node_ids = graph |> Map.keys() |> Enum.sort()
    node_index = node_ids |> Enum.with_index() |> Map.new()

    nodes =
      Enum.map(node_ids, fn id ->
        n = graph[id]

        %{
          "id" => id,
          "name" => n["name"],
          "resource_type" => n["resource_type"],
          "resource_yield" => n["resource_yield"],
          "max_reserve" => get_in(n, ["reserve", "max"]),
          "position" => n["position"],
          "neighbors" => n["neighbors"] |> Enum.map(&node_index[&1]) |> Enum.sort()
        }
      end)

    acc = %{beings: [], being_index: %{}, strings: [], string_index: %{}, frames: [], events: [], seq: 0}
    acc = record_frame(acc, 0, node_ids, node_index, true)

    acc =
      Enum.reduce(1..ticks, acc, fn tick, acc ->
        step(tick)
        player()
        acc = collect_events(acc)

        if rem(tick, every) == 0 do
          frame_no = div(tick, every)
          acc = record_frame(acc, tick, node_ids, node_index, rem(frame_no, @bond_every) == 0)
          if rem(tick, 100) == 0, do: Mix.shell().info("tick #{tick}/#{ticks}")
          acc
        else
          acc
        end
      end)

    replay = %{
      "meta" => %{
        "ticks" => ticks,
        "every" => every,
        "seed" => seed,
        "tick_clock_ms" => @tick_clock_ms,
        "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "resources" => Eldritch.Node.Resource.get_resource_types(),
        "max_ichor" => Eldritch.Being.max_ichor(),
        "max_population" => System.Communion.max_population(),
        "frame_format" =>
          "b: [being, ichor, node, faded, intent*, thought*, desire*, [res*, n, ...], bonds [being, affinity, ...] or null (unchanged), known, visited, age, box, awaiting, streak, lack, jouissance, real‰, symbolic‰, imaginary‰, knot* or -1, identification being or -1, symptom node or -1, symptom cause* or -1, reason*, [chain*], objet a*]; o: big Other [resource*, weight×100, ...]; * = index into strings"
      },
      "nodes" => nodes,
      "beings" => Enum.reverse(acc.beings),
      "strings" => Enum.reverse(acc.strings),
      "frames" => Enum.reverse(acc.frames),
      "events" => Enum.reverse(acc.events)
    }

    File.mkdir_p!(out)
    json = Jason.encode!(replay)
    File.write!(Path.join(out, "replay.json"), json)
    File.write!(Path.join(out, ".nojekyll"), "")

    page =
      Application.app_dir(:lofi, "priv/static/index.html")
      |> File.read!()
      |> String.replace(~s(<html lang="en">), ~s(<html lang="en" data-replay="replay.json">), global: false)

    File.write!(Path.join(out, "index.html"), page)

    Eldritch.Genesis.reset()
    Eldritch.Clock.reset()

    Mix.shell().info(
      "Recorded #{length(replay["frames"])} frames, #{length(replay["beings"])} beings, " <>
        "#{length(replay["events"])} events (#{div(byte_size(json), 1024)} KB) into #{out}/"
    )
  end

  # run every system once, in the same proportions as the live simulation
  defp step(tick) do
    Eldritch.Clock.advance(@tick_clock_ms)

    systems =
      [System.Volition, System.Observation, System.TemporalDecay, System.Remind] ++
        if(rem(tick, 2) == 0, do: [System.Harvest, System.Communion], else: []) ++
        if rem(tick, 4) == 0, do: [System.Regrowth], else: []

    Enum.each(systems, fn system ->
      system.update_components(system)
      Eldritch.Genesis.flush()
    end)
  end

  # a simulated player answers some whispered incantations
  defp player() do
    for being <- Entities.being_list(),
        card = Eldritch.Being.Deck.awaiting(being["deck"]),
        card != nil,
        :rand.uniform() < @answer_chance do
      answer =
        if :rand.uniform() < @correct_chance,
          do: card["back"],
          else: "a half remembered word"

      Eldritch.Being.recall(being["id"], answer)
    end

    Eldritch.Genesis.flush()
  end

  defp collect_events(acc) do
    new = Eldritch.Chronicle.since(acc.seq, 10_000)

    case new do
      [] ->
        acc

      [%{"seq" => latest} | _] ->
        events =
          Enum.reduce(Enum.reverse(new), acc.events, fn e, events ->
            [Map.take(e, ["seq", "kind", "text", "tick", "beings", "node"]) | events]
          end)

        %{acc | events: events, seq: latest}
    end
  end

  defp record_frame(acc, tick, node_ids, node_index, with_bonds?) do
    graph = Entities.node_map()
    reserves = Enum.map(node_ids, &(get_in(graph, [&1, "reserve", "amount"]) || 0))

    beings = Entities.being_list() |> Enum.sort_by(& &1["id"])

    {acc, rows} =
      Enum.reduce(beings, {acc, []}, fn b, {acc, rows} ->
        {acc, bi} = being_index(acc, b)
        {acc, intent} = intern(acc, get_in(b, ["volition", "intent"]) || "")
        {acc, thought} = intern(acc, get_in(b, ["volition", "thought"]) || "")
        {acc, desire} = intern(acc, get_in(b, ["volition", "desire"]) || "")

        {acc, resources} =
          (get_in(b, ["inventory", "resources"]) || %{})
          |> Enum.sort()
          |> Enum.reduce({acc, []}, fn {r, n}, {acc, flat} ->
            {acc, ri} = intern(acc, r)
            {acc, flat ++ [ri, n]}
          end)

        {acc, bonds} =
          if with_bonds? do
            (b["bonds"] || %{})
            |> Enum.reduce({acc, []}, fn {other, aff}, {acc, flat} ->
              {acc, oi} = being_index_id(acc, other)
              {acc, flat ++ [oi, aff]}
            end)
          else
            {acc, nil}
          end

        incantation = Eldritch.Being.Deck.current(b["deck"]) || %{"box" => 1, "streak" => 0}
        psyche = Eldritch.Lacan.normalize(b["psyche"])
        regs = psyche["registers"]
        {acc, knot} = intern_or_none(acc, psyche["knot"])
        {acc, ident} = if psyche["identification"], do: being_index_id(acc, psyche["identification"]), else: {acc, -1}
        symptom = psyche["symptom"]
        symptom_node = if symptom, do: Map.get(node_index, symptom["node"], -1), else: -1
        {acc, cause} = intern_or_none(acc, symptom && symptom["cause"])
        {acc, reason} = intern(acc, psyche["reason"] || "")
        {acc, objet_a} = intern(acc, psyche["objet_a"])

        {acc, chain} =
          Enum.reduce(psyche["chain"], {acc, []}, fn r, {acc, flat} ->
            {acc, ri} = intern(acc, r)
            {acc, flat ++ [ri]}
          end)

        row = [
          bi,
          b["ichor"] || 0,
          Map.get(node_index, b["at_node"], -1),
          if(Entities.alive?(b), do: 0, else: 1),
          intent,
          thought,
          desire,
          resources,
          bonds,
          map_size(get_in(b, ["observations", "nodes"]) || %{}),
          map_size(get_in(b, ["observations", "visited"]) || %{}),
          # seconds of (recorded) life
          div(Eldritch.Being.Life.age_ms(b["lineage"]), 1000),
          incantation["box"],
          if(incantation["awaiting"], do: 1, else: 0),
          incantation["streak"],
          round(psyche["lack"]),
          round(psyche["jouissance"]),
          round(1000 * regs["real"]),
          round(1000 * regs["symbolic"]),
          round(1000 * regs["imaginary"]),
          knot,
          ident,
          symptom_node,
          cause,
          reason,
          chain,
          objet_a
        ]

        {acc, [row | rows]}
      end)

    {acc, other} =
      Eldritch.Lacan.stored_big_other()
      |> Enum.reduce({acc, []}, fn {r, v}, {acc, flat} ->
        {acc, ri} = intern(acc, r)
        {acc, flat ++ [ri, round(v * 100)]}
      end)

    frame = %{
      "t" => tick,
      "now" => Eldritch.Clock.now_ms(),
      "r" => reserves,
      "o" => other,
      "b" => Enum.reverse(rows)
    }

    %{acc | frames: [frame | acc.frames]}
  end

  defp being_index(acc, b) do
    case Map.fetch(acc.being_index, b["id"]) do
      {:ok, i} ->
        {acc, i}

      :error ->
        incantation = Eldritch.Being.Deck.current(b["deck"]) || %{}

        info = %{
          "id" => b["id"],
          "name" => b["name"],
          "generation" => get_in(b, ["lineage", "generation"]) || 0,
          "parents" => get_in(b, ["lineage", "parents"]) || [],
          "lifespan" => div(Eldritch.Being.Life.normalize(b["lineage"])["lifespan_ms"], 1000),
          "front" => incantation["front"],
          "has_back" => (incantation["back"] || "") != ""
        }

        i = map_size(acc.being_index)
        {%{acc | beings: [info | acc.beings], being_index: Map.put(acc.being_index, b["id"], i)}, i}
    end
  end

  # bonds may point at a being not yet recorded (e.g. just summoned)
  defp being_index_id(acc, id) do
    case Map.fetch(acc.being_index, id) do
      {:ok, i} ->
        {acc, i}

      :error ->
        case Cosmos.Entity.Cache.lookup(id) do
          nil -> {acc, -1}
          pid -> being_index(acc, Entities.values(pid))
        end
    end
  end

  defp intern_or_none(acc, nil), do: {acc, -1}
  defp intern_or_none(acc, s), do: intern(acc, s)

  defp intern(acc, s) do
    case Map.fetch(acc.string_index, s) do
      {:ok, i} ->
        {acc, i}

      :error ->
        i = map_size(acc.string_index)
        {%{acc | strings: [s | acc.strings], string_index: Map.put(acc.string_index, s, i)}, i}
    end
  end
end
