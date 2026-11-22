defmodule Lofi.Portrait.Prompt do
  @moduledoc """
  Describes a portrait in words: the prompt an image model is given
  (`Lofi.Portrait.ImageModel`), also handy for agents and alt text.
  """

  @style "Lo-fi eldritch portrait, risograph print look: flat muted inks, coarse paper " <>
           "grain, bold ink outlines, centred bust on a plain dark ground, no text."

  @palettes %{
    "verdigris" => "verdigris green and putty",
    "oxblood" => "oxblood red and bone white",
    "ochre" => "ochre and burnt umber",
    "dusk" => "dusky lilac and pale green",
    "seaglass" => "sea-glass blue and coral",
    "moss" => "moss green and rust",
    "bone" => "bone and soot",
    "ember" => "charcoal grey and ember orange"
  }

  @forms %{
    "bulb" => "a bulbous, swollen head",
    "spire" => "a tall, tapering spire of a body",
    "maw" => "a wide, squat body that is mostly mouth",
    "cluster" => "a cluster of fused orbs",
    "veil" => "a hooded, veiled shape"
  }

  def build(%{"anatomy" => a, "mood" => m} = f) do
    name = Map.get(f, "name")

    [
      @style,
      "A being#{if name, do: " named #{name}", else: ""}: #{@forms[a["form"]]}, " <>
        "#{count(a["eyes"], "eye")}#{limbs(a)}, marked with #{a["markings"]}, " <>
        "in #{@palettes[a["palette"]]}.",
      mood(m)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  def build(features), do: build(Map.put_new(features, "mood", %{}))

  defp limbs(%{"limbs" => "none"}), do: ""
  defp limbs(%{"limbs" => kind, "limb_count" => n}), do: " and #{n} #{kind}"

  defp mood(m) do
    [
      m["faded"] && "It has faded: grey, eyes closed, a husk.",
      !m["faded"] && vigor(m["vigor"]),
      !m["faded"] && (m["lack"] || 0) >= 3 && "Its pupils are wide with longing.",
      m["register"] == "real" && "Its outline is jagged and raw.",
      m["register"] == "symbolic" && "A ring of runes hangs above it.",
      m["register"] == "imaginary" && "It is mirror-symmetric and shimmers.",
      m["unknotted"] && "The ring around it is broken.",
      m["mourning"] && "A tear runs from one eye.",
      m["desire"] && "It longs for #{String.replace(m["desire"], "_", " ")}."
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end

  defp vigor(v) when v in [0, 1], do: "It looks starved and pale."
  defp vigor(v) when v >= 4, do: "It glows with ichor."
  defp vigor(_), do: nil

  defp count(1, noun), do: "one #{noun}"
  defp count(n, noun), do: "#{n} #{noun}s"
end
