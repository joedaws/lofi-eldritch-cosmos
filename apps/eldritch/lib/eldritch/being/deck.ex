defmodule Eldritch.Being.Deck do
  @moduledoc """
  A being's deck of incantations (flash cards).

  Each card is an `Eldritch.Being.Incantation` with an `"id"`, reviewed on
  its own Leitner schedule. A being whispers at most one card at a time:
  when nothing is awaiting an answer, the card that has been due longest
  starts being whispered.

  The deck is stored as `%{"cards" => [card, ...]}`.
  """
  alias Eldritch.Being.Incantation

  @max_cards 30
  @max_text 200

  def max_cards(), do: @max_cards

  def new(cards \\ []) do
    Enum.reduce(cards, %{"cards" => []}, fn card, deck ->
      case add(deck, card["front"], card["back"]) do
        {:ok, deck, _card} -> deck
        _ -> deck
      end
    end)
  end

  @doc "Accepts a deck, an old single incantation, or nil"
  def normalize(%{"cards" => cards}) when is_list(cards) do
    %{"cards" => Enum.map(cards, &normalize_card/1)}
  end

  def normalize(%{"front" => _} = single), do: %{"cards" => [normalize_card(single)]}
  def normalize(_), do: %{"cards" => []}

  defp normalize_card(card) do
    card
    |> Incantation.normalize()
    |> Map.put_new_lazy("id", &card_id/0)
  end

  def cards(deck), do: normalize(deck)["cards"]

  @doc "The card being whispered, if any"
  def awaiting(deck), do: Enum.find(cards(deck), & &1["awaiting"])

  @doc "The card being whispered, or else the next one due"
  def current(deck) do
    awaiting(deck) || Enum.min_by(cards(deck), & &1["due_at"], fn -> nil end)
  end

  def add(deck, front, back) do
    deck = normalize(deck)

    with {:ok, front, back} <- clean(front, back),
         true <- length(deck["cards"]) < @max_cards || {:error, :deck_full} do
      card = Incantation.new(front, back) |> Map.put("id", card_id())
      {:ok, %{deck | "cards" => deck["cards"] ++ [card]}, card}
    end
  end

  @doc "Rewrites a card (its review progress starts over)"
  def update(deck, id, front, back) do
    deck = normalize(deck)

    with {:ok, front, back} <- clean(front, back),
         true <- Enum.any?(deck["cards"], &(&1["id"] == id)) || {:error, :no_card} do
      cards =
        Enum.map(deck["cards"], fn
          %{"id" => ^id} -> Incantation.new(front, back) |> Map.put("id", id)
          card -> card
        end)

      {:ok, %{deck | "cards" => cards}}
    end
  end

  def delete(deck, id) do
    deck = normalize(deck)

    if Enum.any?(deck["cards"], &(&1["id"] == id)),
      do: {:ok, %{deck | "cards" => Enum.reject(deck["cards"], &(&1["id"] == id))}},
      else: {:error, :no_card}
  end

  @doc """
  If nothing is awaiting, starts whispering the card due longest.
  Returns `{whispered_card | nil, deck}`.
  """
  def whisper(deck) do
    deck = normalize(deck)

    due =
      deck["cards"]
      |> Enum.filter(&(Incantation.type(&1) != :empty and Incantation.due?(&1)))
      |> Enum.min_by(& &1["due_at"], fn -> nil end)

    if awaiting(deck) == nil and due do
      card = %{due | "awaiting" => true}
      {card, replace(deck, card)}
    else
      {nil, deck}
    end
  end

  @doc """
  Answers the whispered card. Returns `{:ok, result, deck}` or
  `{:error, :not_awaiting, ms_until_next_due}`.
  """
  def answer(deck, answer) do
    deck = normalize(deck)

    case awaiting(deck) do
      nil ->
        next = current(deck)
        due_in = if next, do: max(0, next["due_at"] - Eldritch.Clock.now_ms()), else: nil
        {:error, :not_awaiting, due_in}

      card ->
        correct = Incantation.correct?(card, answer)
        updated = if correct, do: Incantation.promote(card), else: Incantation.demote(card)

        result = %{
          "card_id" => card["id"],
          "front" => card["front"],
          "box_before" => card["box"],
          "correct" => correct,
          "expected" => card["back"],
          "ichor_gain" => if(correct, do: Incantation.reward(card), else: 0),
          "box" => updated["box"],
          "due_at" => updated["due_at"]
        }

        {:ok, result, replace(deck, updated)}
    end
  end

  defp replace(deck, card) do
    %{deck | "cards" => Enum.map(deck["cards"], &if(&1["id"] == card["id"], do: card, else: &1))}
  end

  defp clean(front, back) do
    front = front |> to_string() |> String.trim()
    back = (back || "") |> to_string() |> String.trim()

    cond do
      front == "" -> {:error, :empty_front}
      String.length(front) > @max_text or String.length(back) > @max_text -> {:error, :too_long}
      true -> {:ok, front, back}
    end
  end

  defp card_id(), do: :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)
end
