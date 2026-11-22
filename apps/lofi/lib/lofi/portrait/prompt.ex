defmodule Lofi.Portrait.Prompt do
  @moduledoc """
  Describes a portrait in words: the prompt an image model is given
  (`Lofi.Portrait.ImageModel`), also handy for agents and alt text.
  """

  @style "Eldritch creature portrait as a black-and-white manga ink drawing: heavy spotted " <>
           "blacks, dense cross-hatching in the shadows, screentone greys, bold varied linework, " <>
           "the creature looming large and cropped by the frame, no colour, no text."

  @tones %{
    "light" => "its hide a pale screentone",
    "mid" => "its hide a mid-grey screentone",
    "dark" => "its hide near-black ink with white highlights"
  }

  @grounds %{
    "focus" => "radiating manga focus lines behind it",
    "structure" => "vast hatched megastructure pillars behind it",
    "rain" => "slanting rain hatched across the background",
    "void" => "a black void behind it, lit only at its edges"
  }

  @heroes %{
    "great_eye" => "one enormous staring eye",
    "crown" => "a crown of horns",
    "antlers" => "great branching antlers",
    "frill" => "a spiked frill fanned out behind its head",
    "halo_eyes" => "a halo set with small eyes",
    "mask" => "a pale mask for a face",
    "maw" => "a gaping toothed maw",
    "beard" => "a beard of tentacles"
  }

  @forms %{
    "bulb" => "an enormous head on a small body",
    "spire" => "a small head on a long neck rising from a tall body",
    "maw" => "a wide, squat body with a small sunken head",
    "cluster" => "a body bearing several heads on stalks",
    "veil" => "a tall hood, its face lost in shadow but for its eyes"
  }

  def build(%{"anatomy" => a, "mood" => m} = f) do
    name = Map.get(f, "name")

    [
      @style,
      "A being#{if name, do: " named #{name}", else: ""}: #{@forms[a["form"]]}, " <>
        "#{count(a["eyes"], "eye")}#{limbs(a)}, marked with #{a["markings"]}, " <>
        "#{@tones[a["tone"]]}#{if a["biomech"], do: ", cables and segmented plates growing from its flesh", else: ""}, " <>
        "#{@grounds[a["ground"]]}." <>
        if(a["hero"], do: " Above all, it has #{@heroes[a["hero"]]}.", else: ""),
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
