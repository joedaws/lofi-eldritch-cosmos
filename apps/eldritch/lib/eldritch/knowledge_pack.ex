defmodule Eldritch.KnowledgePack do
  @moduledoc """
  Stock incantations the seeded beings are instilled with.
  """

  @packs %{
    "multiplication" =>
      for(
        a <- 3..9,
        b <- a..9,
        do: %{"front" => "#{a} × #{b}", "back" => "#{a * b}"}
      ),
    "calculus" => [
      %{"front" => "d/dx sin(x)", "back" => "cos(x)"},
      %{"front" => "d/dx cos(x)", "back" => "-sin(x)"},
      %{"front" => "d/dx e^x", "back" => "e^x"},
      %{"front" => "d/dx ln(x)", "back" => "1/x"},
      %{"front" => "d/dx x^n", "back" => "n x^(n-1)"},
      %{"front" => "∫ 1/x dx", "back" => "ln|x| + C"},
      %{"front" => "∫ cos(x) dx", "back" => "sin(x) + C"}
    ],
    "eldritch vocabulary" => [
      %{"front" => "Eldritch", "back" => "weird and sinister or ghostly"},
      %{"front" => "Tenebrous", "back" => "dark and shadowy"},
      %{"front" => "Cimmerian", "back" => "very dark or gloomy"},
      %{"front" => "Ichor", "back" => "the ethereal fluid that flows in the veins of the gods"},
      %{"front" => "Orichalcum", "back" => "a legendary metal of Atlantis"},
      %{"front" => "Grimoire", "back" => "a book of magic spells"},
      %{"front" => "Cartomancy", "back" => "fortune telling with cards"}
    ],
    "declarations" => [
      %{"front" => "Drink some water.", "back" => ""},
      %{"front" => "Stand up and stretch.", "back" => ""},
      %{"front" => "Breathe in for four, out for six.", "back" => ""}
    ]
  }

  def packs(), do: Map.keys(@packs)

  def incantations(pack), do: Map.get(@packs, pack, [])

  def random_incantation() do
    @packs |> Map.values() |> List.flatten() |> Enum.random()
  end
end
