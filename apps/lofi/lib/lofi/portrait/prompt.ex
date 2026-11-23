defmodule Lofi.Portrait.Prompt do
  @moduledoc """
  Describes a portrait in words: the prompt an image model is given
  (`Lofi.Portrait.ImageModel`), also handy for agents and alt text.
  """

  @style "Portrait of a hooded figure in a dark robe, its face hidden behind a pale mask, " <>
           "as a black-and-white ink drawing: the robe a near-black silhouette filling the frame, " <>
           "the face inside the hood a black hollow, the mask bare bone-white with hatched " <>
           "shadows, screentone greys, bold linework, no colour, no text."

  @masks %{
    "skull" => "a skull mask with a narrow jaw",
    "oval" => "a smooth oval mask",
    "beak" => "a mask with a long downturned beak",
    "shield" => "a shield-shaped mask, flat-browed and pointed at the chin",
    "moon" => "a round moon-faced mask",
    "slab" => "a tall rectangular slab of a mask",
    "lantern" => "a hexagonal lantern-like mask",
    "visor" => "a narrow visor mask across its eyes, the rest of its face in darkness"
  }

  @eye_shapes %{
    "hollow" => "hollow sockets",
    "round" => "round holes",
    "slit" => "narrow slits",
    "almond" => "almond-shaped holes",
    "ring" => "ringed holes"
  }

  @mouths %{
    "stitches" => "a stitched mouth",
    "grille" => "a barred grille for a mouth",
    "slit" => "a slit mouth",
    "teeth" => "a row of carved teeth",
    "smile" => "a carved smile"
  }

  @crests %{
    "horns" => "curved horns rising from the mask",
    "antlers" => "branching antlers rising from the mask",
    "crown" => "a spiked crown on its brow",
    "halo" => "a halo behind its hood",
    "spikes" => "a fan of spikes around the mask",
    "ears" => "two pointed ears on its hood"
  }

  @marks %{
    "stripe" => "a black stripe down its middle",
    "tears" => "painted tears beneath its eyes",
    "runes" => "small runes",
    "split" => "one half darkened",
    "dots" => "painted dots"
  }

  @hoods %{
    "round" => "a rounded hood",
    "peaked" => "a tall peaked hood",
    "deep" => "a deep, wide hood"
  }

  @grounds %{
    "focus" => "radiating manga focus lines behind it",
    "structure" => "vast hatched megastructure pillars behind it",
    "rain" => "slanting rain hatched across the background",
    "void" => "a black void behind it, the figure lit only at its edges"
  }

  def build(%{"anatomy" => a, "mood" => m} = f) do
    name = Map.get(f, "name")
    mouth = @mouths[a["mouth"]]
    mark = @marks[a["mark"]]
    crest = @crests[a["crest"]]

    [
      @style,
      "A being#{if name, do: " named #{name}", else: ""} in #{@hoods[a["hood"]]}, wearing " <>
        "#{@masks[a["mask"]]} with #{count(a["eyes"], "eye")} as #{@eye_shapes[a["eye_shape"]]}" <>
        "#{if mouth, do: ", #{mouth}", else: ""}#{if mark, do: " and #{mark}", else: ""}" <>
        "#{if crest, do: "; #{crest}", else: ""}; #{@grounds[a["ground"]]}.",
      mood(m)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  def build(features), do: build(Map.put_new(features, "mood", %{}))

  defp mood(m) do
    [
      m["faded"] &&
        "It has faded: its robe gone grey, its mask cracked and askew, its eyes empty.",
      !m["faded"] && vigor(m["vigor"]),
      !m["faded"] && (m["lack"] || 0) >= 3 && "Its pupils are wide with longing.",
      m["register"] == "real" && "Its mask is cracked.",
      m["register"] == "symbolic" && "A ring of runes hangs about its head.",
      m["register"] == "imaginary" &&
        "Its mask sits perfectly straight, a faint double beside it.",
      m["unknotted"] && "The ring around it is broken.",
      m["mourning"] && "A tear runs from one eye.",
      m["generosity"] == 2 && !m["faded"] && "It holds out an open hand.",
      m["wanderlust"] == 2 && "It carries a wanderer's staff.",
      m["desire"] && "It longs for #{String.replace(m["desire"], "_", " ")}."
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end

  defp vigor(v) when v in [0, 1], do: "Its mask hangs askew; it looks starved."
  defp vigor(v) when v >= 4, do: "Its eyes blaze with ichor."
  defp vigor(_), do: nil

  defp count(1, noun), do: "one #{noun}"
  defp count(n, noun), do: "#{n} #{noun}s"
end
