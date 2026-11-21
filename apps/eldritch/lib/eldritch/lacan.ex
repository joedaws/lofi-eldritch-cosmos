defmodule Eldritch.Lacan do
  @moduledoc """
  Computational Lacanian dynamics: the psyche of a being.

  Every being carries a `"psyche"` component:

    * `"objet_a"` - the object-cause of desire. A resource the being never
      desires directly; every desire stands in for it. Coming too close to
      it (holding too much of it) produces *anxiety*: anxiety is the lack
      of lack.
    * `"chain"` - the signifying chain: the being's past objects of desire,
      most recent first. Desire slides along it (metonymy) and old
      signifiers return (repetition).
    * `"lack"` (0..100) - how acutely the being lacks. It grows every tick,
      drops when desire is attained (never to zero: desire is never
      satisfied) and barely moves when a demand is answered: a gift
      answers the demand for love, not desire.
    * `"registers"` - the Borromean knot of the Real, Symbolic and
      Imaginary, as weights summing to 1. Gifts and exchange strengthen the
      Symbolic, mirroring and rivalry the Imaginary, loss and starvation
      the Real. Each slowly drifts back toward balance; when one register
      dominates (> #{0.55}) the knot *loosens* and behaviour changes, until
      it falls back below #{0.47} and the knot holds again. `"knot"` holds
      the loosened register (or nil).
    * `"identification"` - the semblable, the being whose image this being
      identifies with (Imaginary). Its desire is contagious.
    * `"symptom"` - after a trauma (a bonded being fading), the place of the
      loss. The being compulsively returns there until it works it through.
    * `"jouissance"` (0..100) - the surplus enjoyment of attaining an object,
      which fades and must be repeated.
    * `"reason"` - why the current desire was taken up (for the curious).

  Need (hunger) is answered by eating. Desire is never answered: when its
  object is attained it slides to another object, chosen by mixing

    * the desire of the big Other - what the whole cosmos currently desires
      and gives (weighted by the Symbolic register),
    * the desire of the semblable (weighted by the Imaginary register),
    * the return of old signifiers from the being's own chain (weighted by
      the Real register: repetition),
    * contiguity - what lies beside the being (metonymy proper).
  """

  @registers ["real", "symbolic", "imaginary"]
  @unknot 0.55
  # the knot only reties once the dominant register falls back below this
  @retie 0.47
  @chain_length 6

  def registers(), do: @registers
  def unknot_threshold(), do: @unknot

  @doc "A fresh psyche. `objet_a` and the start of the chain may be given."
  def new(opts \\ %{}) do
    resources = Eldritch.Node.Resource.get_resource_types()
    objet_a = Map.get_lazy(opts, "objet_a", fn -> Enum.random(resources) end)

    %{
      "objet_a" => objet_a,
      "chain" =>
        Map.get(opts, "chain", [])
        |> Enum.reject(&(&1 == objet_a or is_nil(&1)))
        |> Enum.uniq()
        |> Enum.take(@chain_length),
      "lack" => Map.get(opts, "lack", 30),
      "registers" => %{"real" => 1 / 3, "symbolic" => 1 / 3, "imaginary" => 1 / 3},
      "identification" => Map.get(opts, "identification"),
      "symptom" => nil,
      "jouissance" => 0,
      "knot" => nil,
      "reason" => Map.get(opts, "reason", "it was given at the beginning")
    }
  end

  @doc "Fills in fields missing from older psyches"
  def normalize(nil), do: new()
  def normalize(psyche), do: Map.merge(new(%{"objet_a" => psyche["objet_a"]}), psyche)

  @doc "A desire that is not the objet a"
  def initial_desire(objet_a) do
    Eldritch.Node.Resource.get_resource_types() |> List.delete(objet_a) |> Enum.random()
  end

  # ---------- registers ----------

  @doc "Shifts weight toward `register` by `amount`, keeping the sum at 1"
  def strengthen(psyche, register, amount) when register in @registers do
    regs = Map.update!(psyche["registers"], register, &(&1 + amount))
    %{psyche | "registers" => normalize_registers(regs)} |> update_knot()
  end

  @doc "The register that has loosened the knot, else nil"
  def unknotted(psyche), do: psyche["knot"]

  # loosen above @unknot, retie below @retie (hysteresis, so the knot does not flicker)
  defp update_knot(psyche) do
    {register, weight} = Enum.max_by(psyche["registers"], &elem(&1, 1))

    knot =
      case psyche["knot"] do
        nil -> if weight > @unknot, do: register, else: nil
        loose -> if weight(psyche, loose) < @retie, do: nil, else: loose
      end

    Map.put(psyche, "knot", knot)
  end

  def weight(psyche, register), do: get_in(psyche, ["registers", register]) || 1 / 3

  defp normalize_registers(regs) do
    regs = Map.new(regs, fn {k, v} -> {k, max(v, 0.02)} end)
    total = regs |> Map.values() |> Enum.sum()
    Map.new(regs, fn {k, v} -> {k, Float.round(v / total, 4)} end)
  end

  # ---------- the passage of time ----------

  @doc """
  One tick of psychic life: lack grows (faster when the Real presses) but
  eases while the being draws near its object (`near_object?`), jouissance
  fades and the registers drift back toward balance.
  """
  def tick(psyche, starving?, near_object? \\ false) do
    real = weight(psyche, "real")
    lack_change = if near_object?, do: -1.5, else: 0.3 + 0.5 * real

    regs =
      psyche["registers"]
      |> Map.new(fn {k, v} -> {k, v + (1 / 3 - v) * 0.02} end)
      |> normalize_registers()

    psyche =
      %{
        psyche
        | "lack" => clamp(max(10, psyche["lack"] + lack_change)),
          "jouissance" => clamp(psyche["jouissance"] * 0.95),
          "registers" => regs
      }
      |> update_knot()

    if starving?, do: strengthen(psyche, "real", 0.01), else: psyche
  end

  @doc "Attaining the object of desire: lack falls (never to nothing), jouissance surges"
  def attain(psyche) do
    %{psyche | "lack" => max(10, psyche["lack"] - 45), "jouissance" => clamp(psyche["jouissance"] + 40)}
  end

  @doc "A demand answered: love, not satisfaction"
  def demand_answered(psyche) do
    %{psyche | "lack" => max(10, psyche["lack"] - 6)}
    |> strengthen("symbolic", 0.03)
  end

  @doc "A demand refused: frustration"
  def demand_refused(psyche) do
    %{psyche | "lack" => clamp(psyche["lack"] + 4)}
    |> strengthen("imaginary", 0.01)
  end

  @doc "An encounter with the Real: a bonded being fades"
  def trauma(psyche, node_id, cause) do
    %{psyche | "symptom" => %{"node" => node_id, "cause" => cause, "visits" => 0}}
    |> strengthen("real", 0.15)
  end

  @doc "Returning to the place of the symptom works it through, a little"
  def work_through(psyche) do
    case psyche["symptom"] do
      nil ->
        psyche

      %{"visits" => visits} when visits >= 2 ->
        %{psyche | "symptom" => nil} |> strengthen("symbolic", 0.05)

      symptom ->
        %{psyche | "symptom" => Map.update(symptom, "visits", 1, &(&1 + 1))}
    end
  end

  # ---------- metonymy: choosing the next object ----------

  @doc """
  Chooses the next object of desire. `context` holds:

    * `:other` - `%{resource => weight}` the desire of the big Other
    * `:semblable_desire` - what the identified-with being desires (or nil)
    * `:contiguous` - resources lying beside the being

  Returns `{resource, reason}`.
  """
  def next_desire(psyche, current, context) do
    objet_a = psyche["objet_a"]
    other = Map.get(context, :other, %{})
    max_other = other |> Map.values() |> Enum.max(fn -> 1 end) |> max(1)
    semblable = Map.get(context, :semblable_desire)
    contiguous = Map.get(context, :contiguous, [])
    chain = psyche["chain"]

    s = weight(psyche, "symbolic")
    i = weight(psyche, "imaginary")
    r = weight(psyche, "real")

    candidates =
      Eldritch.Node.Resource.get_resource_types()
      |> Enum.reject(&(&1 == objet_a or &1 == current))

    scored =
      for c <- candidates do
        pulls = %{
          other: 3 * s * Map.get(other, c, 0) / max_other,
          semblable: if(c == semblable, do: 3 * i, else: 0),
          repetition: if(c in chain, do: 2 * r, else: 0),
          contiguity: if(c in contiguous, do: 0.6, else: 0)
        }

        {c, pulls, 0.15 + Enum.sum(Map.values(pulls))}
      end

    {choice, pulls, _} = weighted_random(scored)
    {choice, reason(pulls, choice, Map.get(context, :semblable_name))}
  end

  @doc """
  Pushes the abandoned object onto the signifying chain. The chain holds
  past objects only: a returning signifier leaves the chain while it is
  desired again.
  """
  def slide(psyche, old_desire, new_desire, reason) do
    chain =
      [old_desire | psyche["chain"]]
      |> Enum.uniq()
      |> List.delete(new_desire)
      |> Enum.take(@chain_length)

    %{psyche | "chain" => chain, "reason" => reason}
  end

  defp reason(pulls, choice, semblable_name) do
    {strongest, value} = Enum.max_by(pulls, &elem(&1, 1))
    thing = pretty(choice)

    cond do
      value <= 0.05 -> "#{thing} appeared, from nowhere"
      strongest == :other -> "the Other desires #{thing}"
      strongest == :semblable -> "#{semblable_name || "the one I mirror"} desires #{thing}"
      strongest == :repetition -> "#{thing} returns, as it did before"
      strongest == :contiguity -> "#{thing} lay beside what I lost"
    end
  end

  defp weighted_random(scored) do
    total = scored |> Enum.map(&elem(&1, 2)) |> Enum.sum()
    pick = :rand.uniform() * total

    Enum.reduce_while(scored, pick, fn {_, _, w} = entry, left ->
      if left <= w, do: {:halt, entry}, else: {:cont, left - w}
    end)
    |> case do
      {_, _, _} = entry -> entry
      _ -> List.last(scored)
    end
  end

  # ---------- the big Other ----------

  @doc """
  The desire of the big Other: how much the cosmos as a whole desires each
  signifier. Desires count once each; objects being given count extra, since
  what circulates in exchange is what the symbolic order values.
  """
  def big_other(beings) do
    desired =
      beings
      |> Enum.filter(&Eldritch.Entities.alive?/1)
      |> Enum.reduce(%{}, fn b, acc ->
        case get_in(b, ["volition", "desire"]) do
          nil -> acc
          d -> Map.update(acc, d, 1, &(&1 + 1))
        end
      end)

    # gifts are remembered for a while, then forgotten
    gifts = lookup(:gifts, %{}) |> Map.new(fn {k, v} -> {k, v * 0.9} end) |> Map.reject(fn {_, v} -> v < 0.1 end)
    put(:gifts, gifts)

    Map.merge(desired, Map.new(gifts, fn {k, v} -> {k, v / 3} end), fn _, a, b -> a + b end)
    |> Map.new(fn {k, v} -> {k, Float.round(v * 1.0, 2)} end)
  end

  @doc "Remembers that `units` of `resource` changed hands"
  def record_gift(resource, units) do
    put(:gifts, Map.update(lookup(:gifts, %{}), resource, units, &(&1 + units)))
  end

  def store_big_other(other), do: put(:big_other, other)
  def stored_big_other(), do: lookup(:big_other, %{})

  defp put(key, value) do
    if :ets.whereis(Eldritch.Simulation) != :undefined,
      do: :ets.insert(Eldritch.Simulation, {{__MODULE__, key}, value})
  end

  defp lookup(key, default) do
    with true <- :ets.whereis(Eldritch.Simulation) != :undefined,
         [{_, value}] <- :ets.lookup(Eldritch.Simulation, {__MODULE__, key}) do
      value
    else
      _ -> default
    end
  end

  # ---------- helpers ----------

  @doc "Atomically updates a being's psyche; returns the new psyche"
  def update(being_server, fun) do
    case Cosmos.Entity.Server.get_and_update_component(being_server, "psyche", fn comp ->
           psyche = fun.(normalize(comp.value))
           {psyche, %{comp | value: psyche}}
         end) do
      {:error, _} -> nil
      psyche -> psyche
    end
  end

  def pretty(resource), do: resource |> to_string() |> String.replace("_", " ")

  defp clamp(x), do: x |> max(0) |> min(100) |> Kernel.*(1.0) |> Float.round(2)
end
