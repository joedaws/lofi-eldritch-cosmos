defmodule Eldritch.LifeTest do
  use ExUnit.Case

  alias Eldritch.Being.{Life, Owned}
  alias Eldritch.Entities

  @hour 60 * 60 * 1000
  @day 24 * @hour

  setup do
    Eldritch.Genesis.reset()
    Eldritch.Clock.reset()
    Eldritch.Landscape.generate(rings: [3, 5])
    Eldritch.Genesis.flush()
    on_exit(&Eldritch.Clock.reset/0)
    :ok
  end

  defp vals(id) do
    Eldritch.Genesis.flush()
    id |> Cosmos.Entity.Cache.server_process() |> Entities.values()
  end

  defp volition!() do
    Eldritch.System.Volition.update_components(Eldritch.System.Volition)
    Eldritch.Genesis.flush()
  end

  test "commons beings age on the clock, not by ticks" do
    id = Eldritch.Being.Builder.build({:new, :being, :standard}, %{"lineage" => %{"lifespan_ms" => @day}})
    assert Life.condition(vals(id)) == :vital

    for _ <- 1..50, do: volition!()
    assert Life.condition(vals(id)) == :vital

    Eldritch.Clock.advance(@day + @hour)
    assert Life.condition(vals(id)) == {:withering, :age}
  end

  test "lifespans are days long by default" do
    {low, high} = Life.lifespan_range()
    assert low >= @day and high <= 4 * @day
  end

  test "owned beings do not age, but wither when their owner neglects them" do
    {:ok, id} = Owned.summon(1, %{"cards" => [%{"front" => "a", "back" => "1"}]})

    Eldritch.Clock.advance(2 * @day)
    assert Life.condition(vals(id)) == :vital
    assert Life.grace_left_ms(vals(id)) in (@day - @hour)..(@day + @hour)

    Eldritch.Clock.advance(2 * @day)
    assert Life.condition(vals(id)) == {:withering, :neglect}

    # answering a whisper renews the grace
    Cosmos.Entity.Server.update_component(Cosmos.Entity.Cache.server_process(id), "deck", fn c ->
      %{c | value: %{"cards" => Enum.map(c.value["cards"], &%{&1 | "due_at" => 0})}}
    end)

    Eldritch.System.Remind.update_components(Eldritch.System.Remind)
    assert {:ok, _} = Eldritch.Being.recall(id, "1", 1)
    assert Life.condition(vals(id)) == :vital
  end

  test "a remembered owned being cannot starve; a neglected one can" do
    {:ok, id} = Owned.summon(1, %{})
    pid = Cosmos.Entity.Cache.server_process(id)
    Eldritch.Being.Actions.change_ichor(pid, -1_000)
    volition!()

    v = vals(id)
    assert v["status"] == "alive"
    assert v["ichor"] >= 15
    assert get_in(v, ["volition", "intent"]) == "endure"

    Eldritch.Clock.advance(4 * @day)
    Eldritch.Being.Actions.change_ichor(pid, -1_000)
    volition!()
    assert vals(id)["status"] == "faded"
  end

  test "a dwindling cosmos dreams new beings at the Heart" do
    Eldritch.Genesis.reset()
    Eldritch.Landscape.generate(rings: [3])
    Eldritch.Genesis.flush()
    Application.put_env(:eldritch, :dream_interval_ticks, 1)
    on_exit(fn -> Application.put_env(:eldritch, :dream_interval_ticks, 60) end)

    assert Eldritch.Being.all_ids() == []
    volition!()

    [id] = Eldritch.Being.all_ids()
    heart = Enum.find(Entities.node_map(), fn {_, n} -> n["name"] == "The Heart of the Cosmos" end) |> elem(0)
    assert vals(id)["at_node"] == heart
    assert Enum.any?(Eldritch.Chronicle.recent(5), &(&1["text"] =~ "dreams a new being"))
  end

  test "husks of the commons crumble after a day; owned husks never do" do
    commons = Eldritch.Being.Builder.build({:new, :being, :standard}, %{"ichor" => 0})
    {:ok, owned} = Owned.summon(1, %{})
    Eldritch.Clock.advance(4 * @day)
    Eldritch.Being.Actions.change_ichor(Cosmos.Entity.Cache.server_process(owned), -1_000)
    volition!()

    assert vals(commons)["status"] == "faded"
    assert vals(owned)["status"] == "faded"

    Eldritch.Clock.advance(@day + @hour)
    volition!()

    refute commons in Eldritch.Being.all_ids()
    assert Cosmos.Database.get(commons) == nil
    assert owned in Eldritch.Being.all_ids()
  end

  test "lineages counted in ticks are upgraded to the clock" do
    old = %{"generation" => 2, "parents" => ["a"], "age" => 600, "lifespan" => 700}
    new = Life.normalize(old)
    assert new["generation"] == 2
    assert Life.age_ms(new) in 599_000..601_000
    assert new["lifespan_ms"] >= @day
  end
end
