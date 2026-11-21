defmodule Eldritch.LacanTest do
  use ExUnit.Case

  alias Eldritch.Lacan
  alias Eldritch.Entities

  setup do
    Eldritch.Genesis.reset()
    :ok
  end

  defp vals(id) do
    Eldritch.Genesis.flush()
    id |> Cosmos.Entity.Cache.server_process() |> Entities.values()
  end

  defp set_psyche(id, fun) do
    Lacan.update(Cosmos.Entity.Cache.server_process(id), fun)
    Eldritch.Genesis.flush()
  end

  defp volition!(), do: Eldritch.System.Volition.update_components(Eldritch.System.Volition)

  test "desire never takes the objet a, nor stays where it was" do
    psyche = Lacan.new(%{"objet_a" => "bone", "chain" => ["blood", "papyrus"]})

    for _ <- 1..300 do
      {next, reason} =
        Lacan.next_desire(psyche, "blood", %{other: %{"bone" => 9, "obsidian" => 3}, contiguous: ["sea_foam"]})

      refute next in ["bone", "blood"]
      assert is_binary(reason)
    end
  end

  test "the desire of the Other pulls a symbolic subject" do
    psyche = Lacan.new(%{"objet_a" => "bone"}) |> Lacan.strengthen("symbolic", 2.0)

    picks =
      for _ <- 1..300 do
        {next, _} = Lacan.next_desire(psyche, "blood", %{other: %{"obsidian" => 10}})
        next
      end

    assert Enum.count(picks, &(&1 == "obsidian")) > 150
  end

  test "registers stay a distribution and the knot loosens and reties with hysteresis" do
    psyche = Lacan.new() |> Lacan.strengthen("imaginary", 1.0)
    assert_in_delta psyche["registers"] |> Map.values() |> Enum.sum(), 1.0, 0.001
    assert Lacan.unknotted(psyche) == "imaginary"

    # drifting back toward balance, the knot only holds again well below the threshold
    ticks =
      Stream.iterate(psyche, &Lacan.tick(&1, false))
      |> Enum.take_while(&(Lacan.unknotted(&1) == "imaginary"))

    last = List.last(ticks)
    assert Lacan.weight(last, "imaginary") < Lacan.unknot_threshold()
  end

  test "the signifying chain holds past objects, once each" do
    psyche = Lacan.new(%{"objet_a" => "bone", "chain" => ["blood", "blood", "bone", nil]})
    assert psyche["chain"] == ["blood"]

    psyche = Lacan.slide(psyche, "papyrus", "blood", "it returns")
    assert psyche["chain"] == ["papyrus"]
  end

  test "lack is never fully satisfied" do
    psyche = %{Lacan.new() | "lack" => 50} |> Lacan.attain() |> Lacan.attain() |> Lacan.attain()
    assert psyche["lack"] >= 10
    assert psyche["jouissance"] > 0
  end

  test "beings never begin by desiring their objet a" do
    n = Eldritch.Node.Builder.build({:new, :node}, %{"resource_type" => "bone"})

    for _ <- 1..10 do
      id = Eldritch.Being.Builder.build({:new, :being, :standard}, %{"at_node" => n})
      v = vals(id)
      refute get_in(v, ["volition", "desire"]) == get_in(v, ["psyche", "objet_a"])
    end
  end

  test "anxiety: a being holding too much of its objet a casts it away" do
    n = Eldritch.Node.Builder.build({:new, :node}, %{"resource_type" => "papyrus"})
    id = Eldritch.Being.Builder.build({:new, :being, :standard}, %{"at_node" => n, "desire" => "blood"})
    set_psyche(id, &%{&1 | "objet_a" => "bone"})
    Eldritch.Being.Actions.give_resource(Cosmos.Entity.Cache.server_process(id), "bone", 12)
    Eldritch.Genesis.flush()

    volition!()

    v = vals(id)
    assert get_in(v, ["inventory", "resources", "bone"]) == nil
    assert get_in(v, ["volition", "intent"]) == "anxiety"
  end

  test "beyond the pleasure principle: overwhelming lack overrides hunger" do
    n = Eldritch.Node.Builder.build({:new, :node}, %{"resource_type" => "papyrus"})

    id =
      Eldritch.Being.Builder.build({:new, :being, :standard}, %{
        "at_node" => n,
        "ichor" => 50,
        "desire" => "blood"
      })

    set_psyche(id, &%{&1 | "objet_a" => "bone", "lack" => 95})
    Eldritch.Being.Actions.give_resource(Cosmos.Entity.Cache.server_process(id), "papyrus", 5)
    Eldritch.Genesis.flush()

    volition!()
    refute get_in(vals(id), ["volition", "intent"]) == "consume"
  end

  test "trauma: a bonded being's fading leaves a symptom, and the mourner returns there" do
    a = Eldritch.Node.Builder.build({:new, :node}, %{"resource_type" => "papyrus"})
    b = Eldritch.Node.Builder.build({:new, :node}, %{"resource_type" => "papyrus"})
    Eldritch.Node.Actions.connect_nodes(a, b)

    mourner = Eldritch.Being.Builder.build({:new, :being, :standard}, %{"at_node" => b, "desire" => "blood"})

    lost =
      Eldritch.Being.Builder.build({:new, :being, :standard}, %{
        "at_node" => a,
        "ichor" => 0,
        "bonds" => %{mourner => 20}
      })

    Eldritch.Genesis.flush()
    volition!()

    assert vals(lost)["status"] == "faded"
    symptom = get_in(vals(mourner), ["psyche", "symptom"])
    assert symptom["node"] == a
    assert "trauma" in Enum.map(Eldritch.Chronicle.recent(20), & &1["kind"])

    # with the Real overwhelming, repetition draws the mourner back
    set_psyche(mourner, &Lacan.strengthen(&1, "real", 3.0))
    volition!()
    v = vals(mourner)
    assert get_in(v, ["volition", "intent"]) == "repeat"
    assert v["at_node"] == a

    # standing at the place of loss works the symptom through
    Enum.each(1..4, fn _ -> volition!() end)
    assert get_in(vals(mourner), ["psyche", "symptom"]) == nil
    assert "working_through" in Enum.map(Eldritch.Chronicle.recent(20), & &1["kind"])
  end
end
