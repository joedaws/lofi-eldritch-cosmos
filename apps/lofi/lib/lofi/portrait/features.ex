defmodule Lofi.Portrait.Features do
  @moduledoc """
  What a portrait shows, derived from a being. Plain JSON-able data, so it
  can be cached on, hashed, handed to an image model or to an agent.

  `"anatomy"` depends only on the name (see `anatomy/1`). `"mood"` depends
  on the being's state, bucketed into a few levels each.
  """

  @forms ~w(bulb spire maw cluster veil)
  @limbs ~w(tentacles horns antlers fronds none)
  @markings ~w(rings dots runes veins)
  @palettes ~w(verdigris oxblood ochre dusk seaglass moss bone ember)

  def forms(), do: @forms
  def palettes(), do: @palettes

  @doc "Features of a being view (map with \"name\", \"status\", \"psyche\", …) or of a bare name"
  def from(name) when is_binary(name), do: from(%{"name" => name})

  def from(%{"name" => name} = being) do
    name = String.trim(name || "") |> then(&if(&1 == "", do: "?", else: &1))
    %{"version" => 1, "name" => name, "anatomy" => anatomy(name), "mood" => mood(being)}
  end

  @doc """
  The body a name gives. The number of parts in the name (split on spaces,
  `~` and `-`, as in "Gor Lop~Tome") is the number of eyes; everything else
  comes from a hash of the name.
  """
  def anatomy(name) do
    clean = name |> String.trim() |> String.downcase()
    seed = :erlang.phash2(clean, 4_294_967_296)
    parts = clean |> String.split(~r/[\s~\-]+/, trim: true) |> length()
    limbs = pick(@limbs, seed, :limbs)

    %{
      "seed" => seed,
      "form" => pick(@forms, seed, :form),
      "eyes" => parts |> max(1) |> min(7),
      "limbs" => limbs,
      "limb_count" => if(limbs == "none", do: 0, else: 2 + rem(div(seed, 7), 5)),
      "markings" => pick(@markings, seed, :markings),
      "palette" => pick(@palettes, seed, :palette),
      "symmetric" => rem(div(seed, 13), 3) == 0
    }
  end

  @doc "The being's state as a portrait shows it (an empty map is a calm newborn)"
  def mood(b) do
    psyche = b["psyche"] || %{}
    registers = psyche["registers"] || %{}
    ichor = b["ichor"] || 120
    max = b["max_ichor"] || 200
    temperament = b["temperament"] || %{}

    %{
      "faded" => b["status"] == "faded",
      "vigor" => bucket(ichor / max(max, 1), 4),
      "lack" => bucket((psyche["lack"] || 30) / 100, 4),
      "register" => dominant(registers),
      "unknotted" => psyche["unknotted"] != nil,
      "mourning" => psyche["symptom"] != nil,
      "desire" => b["desire"],
      "objet_a" => psyche["objet_a"],
      "wanderlust" => bucket((temperament["wanderlust"] || 50) / 100, 2),
      "sociability" => bucket((temperament["sociability"] || 50) / 100, 2),
      "whispering" => get_in(b, ["incantation", "awaiting"]) == true
    }
  end

  # a register shows once it clearly leads (the knot loosens at 0.55)
  defp dominant(registers) when map_size(registers) == 0, do: nil

  defp dominant(registers) do
    {k, v} = Enum.max_by(registers, &elem(&1, 1))
    if v >= 0.42, do: k, else: nil
  end

  defp bucket(x, levels), do: x |> max(0.0) |> min(0.999) |> Kernel.*(levels + 1) |> trunc()

  defp pick(list, seed, salt), do: Enum.at(list, rem(:erlang.phash2({seed, salt}), length(list)))
end
