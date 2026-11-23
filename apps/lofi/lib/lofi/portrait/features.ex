defmodule Lofi.Portrait.Features do
  @moduledoc """
  What a portrait shows, derived from a being. Plain JSON-able data, so it
  can be cached on, hashed, handed to an image model or to an agent.

  Every being is the same dark, hooded and robed figure; what tells them
  apart is the **mask** over its face. `"anatomy"` (the mask, its eyes and
  mouth, what crowns it, the hood) depends only on the name (see
  `anatomy/1`). `"mood"` depends on the being's state, bucketed into a few
  levels each.
  """

  # the outline of the mask: the first thing you tell beings apart by
  @masks ~w(skull oval beak shield moon slab lantern visor)
  @eye_shapes ~w(hollow round slit almond ring)
  @mouths ~w(stitches grille slit teeth smile none)
  # what crowns it: breaking the hood's outline, or not
  @crests ~w(none none horns antlers crown halo spikes ears)
  @marks ~w(none stripe tears runes split dots)
  # the mask's own ink: bare bone, or a pale ash screentone
  @inks ~w(bone bone ash)
  @hoods ~w(round peaked deep)
  # what it stands before: manga focus lines, a megastructure, rain, or the void
  @grounds ~w(focus structure rain void)

  def masks(), do: @masks
  def eye_shapes(), do: @eye_shapes
  def mouths(), do: @mouths
  def crests(), do: Enum.uniq(@crests)
  def marks(), do: @marks
  def hoods(), do: @hoods
  def grounds(), do: @grounds

  @doc "Features of a being view (map with \"name\", \"status\", \"psyche\", …) or of a bare name"
  def from(name) when is_binary(name), do: from(%{"name" => name})

  def from(%{"name" => name} = being) do
    name = String.trim(name || "") |> then(&if(&1 == "", do: "?", else: &1))
    %{"version" => 4, "name" => name, "anatomy" => anatomy(name), "mood" => mood(being)}
  end

  @doc """
  The mask a name gives. The number of parts in the name (split on spaces,
  `~` and `-`, as in "Gor Lop~Tome") is the number of eyes in the mask;
  everything else comes from a hash of the name.
  """
  def anatomy(name) do
    clean = name |> String.trim() |> String.downcase()
    seed = :erlang.phash2(clean, 4_294_967_296)
    parts = clean |> String.split(~r/[\s~\-]+/, trim: true) |> length()

    %{
      "seed" => seed,
      "mask" => pick(@masks, seed, :mask),
      "eyes" => parts |> max(1) |> min(7),
      "eye_shape" => pick(@eye_shapes, seed, :eye_shape),
      "mouth" => pick(@mouths, seed, :mouth),
      "crest" => pick(@crests, seed, :crest),
      "mark" => pick(@marks, seed, :mark),
      "ink" => pick(@inks, seed, :ink),
      "hood" => pick(@hoods, seed, :hood),
      "ground" => pick(@grounds, seed, :ground),
      "light" => pick(~w(left right), seed, :light)
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
      "generosity" => bucket((temperament["generosity"] || 50) / 100, 2),
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
