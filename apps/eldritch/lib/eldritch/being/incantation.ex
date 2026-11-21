defmodule Eldritch.Being.Incantation do
  @moduledoc """
  Incantations are flash cards bound to beings, reviewed with a
  Leitner system:

    * every incantation sits in a box (1..#{6})
    * when it is due the being *whispers* it (`"awaiting" => true`)
    * recalling it correctly moves it up a box (longer interval) and
      feeds the being ichor; a wrong answer sends it back to box 1
  """

  # seconds until an incantation in box n is due again
  @intervals %{1 => 20, 2 => 60, 3 => 5 * 60, 4 => 30 * 60, 5 => 2 * 3600, 6 => 24 * 3600}
  @max_box 6

  def default() do
    %{
      "front" => "Breath life into the being with this incantation",
      "back" => "Secrets can strengthen life force"
    }
  end

  def new(front, back) do
    %{
      "front" => to_string(front || ""),
      "back" => to_string(back || ""),
      "box" => 1,
      "due_at" => now() + interval(1),
      "awaiting" => false,
      "streak" => 0,
      "recalls" => 0
    }
  end

  @doc "Fills in spaced repetition fields missing from older incantations"
  def normalize(incantation) when is_map(incantation) do
    Map.merge(new(incantation["front"], incantation["back"]), incantation)
  end

  def type(%{"front" => "", "back" => ""}), do: :empty
  def type(%{"back" => ""}), do: :declarative
  def type(_), do: :flash

  def interval(box), do: Map.fetch!(@intervals, box) * 1000

  def due?(incantation), do: now() >= incantation["due_at"]

  @doc """
  Checks an answer. Declarative incantations only need to be acknowledged.
  """
  def correct?(incantation, answer) do
    case type(incantation) do
      :flash -> normalize_text(answer) == normalize_text(incantation["back"])
      _ -> true
    end
  end

  @doc "ichor granted for a correct recall"
  def reward(incantation), do: 10 + 5 * incantation["box"]

  def promote(incantation) do
    box = min(incantation["box"] + 1, @max_box)

    %{
      incantation
      | "box" => box,
        "due_at" => now() + interval(box),
        "awaiting" => false,
        "streak" => incantation["streak"] + 1,
        "recalls" => incantation["recalls"] + 1
    }
  end

  def demote(incantation) do
    %{
      incantation
      | "box" => 1,
        "due_at" => now() + interval(1),
        "awaiting" => false,
        "streak" => 0,
        "recalls" => incantation["recalls"] + 1
    }
  end

  defp normalize_text(text) do
    text
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[[:punct:]]/u, "")
    |> String.split()
    |> Enum.join(" ")
  end

  defp now(), do: Eldritch.Clock.now_ms()
end
