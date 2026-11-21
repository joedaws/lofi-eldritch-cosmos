defmodule Eldritch.System.Communion do
  @moduledoc """
  Beings that share a node commune. Through communion they learn
  (or fail to learn) cooperation:

    * **meeting**   - beings share what they know of the landscape; a being
                      weighted toward the Imaginary may *identify* with a
                      stronger other, its semblable, whose desire becomes
                      contagious (`Eldritch.Lacan`)
    * **demand**    - a lacking being demands what it desires of one who has
                      it. The other gives (Symbolic: the gift binds them, and
                      answers the demand for love, not desire) or refuses
                      (when it desires the same, bears a grudge, or its knot
                      has loosened toward the Imaginary)
    * **rivalry**   - beings desiring the same dwindling resource quarrel
                      (Imaginary aggressivity toward the semblable)
    * **succor**    - a strong being shares ichor with a fading friend
    * **summoning** - two deeply bonded, vigorous beings summon a new being

  Bonds are stored on each being as `%{other_id => affinity}`.
  """
  require Logger
  alias Eldritch.{Chronicle, Entities}
  alias Eldritch.Being.Actions
  alias Eldritch.Lacan

  @min_affinity -20
  @max_affinity 50
  @max_pairs_per_node 6

  @gift_units 3
  @succor_ichor 15
  @summon_affinity 12
  @summon_ichor 90
  @summon_cost 40
  @summon_chance 0.15

  def max_population(), do: Application.get_env(:eldritch, :max_population, 40)

  def update_components(_system) do
    graph = Entities.node_map()
    beings = Entities.being_list()
    living = Enum.filter(beings, &Entities.alive?/1)
    population = length(living)

    living
    |> Enum.filter(& &1["at_node"])
    |> Enum.group_by(& &1["at_node"])
    |> Enum.reduce(population, fn {node_id, gathered}, population ->
      gathered
      |> pairs()
      |> Enum.take_random(@max_pairs_per_node)
      |> Enum.reduce(population, fn {a, b}, population ->
        try do
          commune(a, b, Map.get(graph, node_id, %{}), population)
        catch
          kind, reason ->
            Logger.warning("communion failed: #{Exception.format(kind, reason)}")
            population
        end
      end)
    end)
  end

  defp pairs(beings) do
    for {a, i} <- Enum.with_index(beings), {b, j} <- Enum.with_index(beings), i < j, do: {a, b}
  end

  # returns the (possibly increased) population
  defp commune(a, b, node, population) do
    meet(a, b, node)
    meet(b, a, node)
    share_knowledge(a, b)
    demand(a, b)
    demand(b, a)
    rivalry(a, b, node)
    succor(a, b)
    succor(b, a)
    summon(a, b, node, population)
  end

  defp meet(a, b, node) do
    if not Map.has_key?(bonds(a), b["id"]) do
      if a["id"] < b["id"] do
        Chronicle.record(
          :meet,
          "#{a["name"]} and #{b["name"]} meet at #{node["name"] || "the edge of things"}.",
          %{"beings" => [a["id"], b["id"]], "node" => node["id"]}
        )
      end
    end

    bond(a, b, 1)
    identify(a, b, node)
  end

  # the mirror: a being leaning toward the Imaginary sees itself in a stronger other
  defp identify(a, b, node) do
    psyche = Lacan.normalize(a["psyche"])
    i = Lacan.weight(psyche, "imaginary")

    # a being keeps its mirror a while: changing it is much rarer than finding one
    stickiness = if psyche["identification"], do: 0.1, else: 1.0

    if psyche["identification"] != b["id"] and (b["ichor"] || 0) > (a["ichor"] || 0) and
         :rand.uniform() < (i - 0.25) * 0.5 * stickiness do
      Lacan.update(a["pid"], fn p ->
        %{p | "identification" => b["id"]} |> Lacan.strengthen("imaginary", 0.03)
      end)

      Chronicle.record(
        :identify,
        "#{a["name"]} sees itself in #{b["name"]}.",
        %{"beings" => [a["id"], b["id"]], "node" => node["id"]}
      )
    end
  end

  defp share_knowledge(a, b) do
    known_a = get_in(a, ["observations", "nodes"]) || %{}
    known_b = get_in(b, ["observations", "nodes"]) || %{}
    learn(a, known_b)
    learn(b, known_a)
  end

  defp learn(being, knowledge) do
    Cosmos.Entity.Server.update_component(being["pid"], "observations", fn comp ->
      Map.update!(comp, :value, fn obs ->
        Map.update(obs, "nodes", knowledge, &Map.merge(knowledge, &1))
      end)
    end)
  end

  # the asker demands what it desires of the holder, who gives or refuses
  defp demand(asker, holder) do
    want = get_in(asker, ["volition", "desire"])
    have = get_in(holder, ["inventory", "resources", want]) || 0
    asker_psyche = Lacan.normalize(asker["psyche"])
    holder_psyche = Lacan.normalize(holder["psyche"])

    if have > 0 and asker_psyche["lack"] > 20 and :rand.uniform() < 0.5 do
      refuse? =
        get_in(holder, ["volition", "desire"]) == want or
          Map.get(bonds(holder), asker["id"], 0) < 0 or
          Lacan.unknotted(holder_psyche) == "imaginary"

      # an owner's temperament: generosity 50 always gives 3, 0 never gives, 100 gives 6
      generosity = Eldritch.Being.Temperament.factor(holder, "generosity")
      refuse? = refuse? or :rand.uniform() > generosity
      units = max(1, round(@gift_units * generosity))
      given = if refuse?, do: 0, else: Actions.take_resource(holder["pid"], want, units)

      if given > 0 do
        Actions.give_resource(asker["pid"], want, given)
        Lacan.record_gift(want, given)
        Lacan.update(asker["pid"], &Lacan.demand_answered/1)
        Lacan.update(holder["pid"], &Lacan.strengthen(&1, "symbolic", 0.02))
        bond(asker, holder, 3)
        bond(holder, asker, 1)

        Chronicle.record(
          :gift,
          "#{asker["name"]} demands #{pretty(want)} of #{holder["name"]}, who gives #{given}. " <>
            "It is love #{asker["name"]} receives, not #{pretty(want)}.",
          %{"beings" => [holder["id"], asker["id"]], "node" => holder["at_node"]}
        )
      else
        Lacan.update(asker["pid"], &Lacan.demand_refused/1)
        bond(asker, holder, -2)

        if :rand.uniform() < 0.1 do
          Chronicle.record(
            :refusal,
            "#{holder["name"]} refuses #{asker["name"]}'s demand for #{pretty(want)}.",
            %{"beings" => [holder["id"], asker["id"]], "node" => holder["at_node"]}
          )
        end
      end
    end
  end

  defp rivalry(a, b, node) do
    desire = get_in(a, ["volition", "desire"])

    if desire == get_in(b, ["volition", "desire"]) and node["resource_type"] == desire and
         (get_in(node, ["reserve", "amount"]) || 0) < 15 do
      # aggressivity toward the semblable grows with the Imaginary
      for {x, y} <- [{a, b}, {b, a}] do
        i = Lacan.weight(Lacan.normalize(x["psyche"]), "imaginary")
        bond(x, y, -round(1 + 3 * i))
        Lacan.update(x["pid"], &Lacan.strengthen(&1, "imaginary", 0.005))
      end

      # quarrels are frequent; only the occasional one makes the chronicle
      if :rand.uniform() < 0.03 do
        Chronicle.record(
          :rivalry,
          "#{a["name"]} and #{b["name"]} quarrel over the dwindling #{pretty(desire)}.",
          %{"beings" => [a["id"], b["id"]], "node" => node["id"]}
        )
      end
    end
  end

  defp succor(giver, receiver) do
    if (receiver["ichor"] || 0) < 30 and (giver["ichor"] || 0) > 80 and
         Map.get(bonds(giver), receiver["id"], 0) >= 5 do
      Actions.change_ichor(giver["pid"], -@succor_ichor)
      Actions.change_ichor(receiver["pid"], @succor_ichor)
      bond(receiver, giver, 5)

      if :rand.uniform() < 0.25,
        do:
          Chronicle.record(
        :succor,
        "#{giver["name"]} shares its ichor with the fading #{receiver["name"]}.",
        %{"beings" => [giver["id"], receiver["id"]], "node" => giver["at_node"]}
      )
    end
  end

  defp summon(a, b, node, population) do
    devoted =
      Map.get(bonds(a), b["id"], 0) >= @summon_affinity and
        Map.get(bonds(b), a["id"], 0) >= @summon_affinity

    vigorous = (a["ichor"] || 0) >= @summon_ichor and (b["ichor"] || 0) >= @summon_ichor

    if devoted and vigorous and population < max_population() and
         :rand.uniform() < summon_chance(population) do
      Actions.change_ichor(a["pid"], -@summon_cost)
      Actions.change_ichor(b["pid"], -@summon_cost)

      generation =
        max(get_in(a, ["lineage", "generation"]) || 0, get_in(b, ["lineage", "generation"]) || 0) +
          1

      child_id =
        Eldritch.Being.Builder.build({:new, :being, :standard}, %{
          "at_node" => a["at_node"],
          "ichor" => 2 * @summon_cost,
          "desire" =>
            Enum.random([get_in(a, ["volition", "desire"]), get_in(b, ["volition", "desire"])]),
          "incantation" => Eldritch.KnowledgePack.random_incantation(),
          "lineage" => %{"generation" => generation, "parents" => [a["id"], b["id"]]},
          "bonds" => %{a["id"] => 15, b["id"] => 15},
          # the child enters a chain of signifiers already begun by its parents;
          # its cause of desire is its own
          "psyche" => %{
            "chain" => [get_in(a, ["volition", "desire"]), get_in(b, ["volition", "desire"])],
            "identification" => Enum.random([a["id"], b["id"]]),
            "reason" => "my parents desired it"
          }
        })

      bond_id(a, child_id, 15)
      bond_id(b, child_id, 15)
      child_name = Cosmos.Entity.Cache.server_process(child_id) |> Cosmos.Entity.Server.value("name")

      Chronicle.record(
        :summon,
        "#{a["name"]} and #{b["name"]} summon a new being, #{child_name}, at #{node["name"]}.",
        %{"beings" => [a["id"], b["id"], child_id], "node" => node["id"]}
      )

      population + 1
    else
      population
    end
  end

  # a dwindling cosmos summons more eagerly (up to 4x below half the population cap)
  defp summon_chance(population) do
    target = max(1, div(max_population(), 2))
    @summon_chance * (1 + 3 * max(0, 1 - population / target))
  end

  defp bonds(being), do: being["bonds"] || %{}

  defp bond(from, to, amount), do: bond_id(from, to["id"], amount)

  defp bond_id(from, to_id, amount) do
    Cosmos.Entity.Server.update_component(from["pid"], "bonds", fn comp ->
      Map.update!(comp, :value, fn bonds ->
        Map.update(bonds, to_id, clamp(amount), &clamp(&1 + amount))
      end)
    end)
  end

  defp clamp(x), do: x |> max(@min_affinity) |> min(@max_affinity)

  defp pretty(resource), do: resource |> to_string() |> String.replace("_", " ")
end
