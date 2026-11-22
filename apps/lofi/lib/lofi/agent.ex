defmodule Lofi.Agent do
  @moduledoc """
  What a person's learning agent can see and do, through a token the
  person created (`Lofi.Accounts.AgentToken`). Used by both the JSON api
  (`/api/agent/…`) and the MCP server (`/mcp`).

  An agent sees only its person's being, deck and history, plus the
  public life of the cosmos. It may edit the deck (add, rewrite and burn
  cards) but never answers whispers: answers keep a being alive because
  they prove the person remembers. An agent can see what is whispered and
  quiz its person instead.
  """
  alias Eldritch.Being.{Deck, Life, Owned, Temperament}
  alias Eldritch.History

  # ---------- the tools ----------

  @tools [
    %{
      name: "my_being",
      description:
        "The person's being in the cosmos: its state, thought, desire, ichor, psyche (lack, " <>
          "registers, symptom), temperament, and how much grace is left before it withers for " <>
          "want of answers. Null if the person has not summoned one yet.",
      input: %{}
    },
    %{
      name: "my_cards",
      description:
        "The being's deck of incantations (flash cards the person studies): front, back, " <>
          "Leitner box (1-6, higher = better remembered), when each is next due, and which one " <>
          "the being is whispering now.",
      input: %{}
    },
    %{
      name: "whispering_now",
      description:
        "The card the being is whispering right now (waiting for the person to answer it in the " <>
          "cosmos), or null. Use it to quiz the person; only they can answer it in the cosmos.",
      input: %{}
    },
    %{
      name: "card_accuracy",
      description:
        "How well the person remembers each card they have answered: answers, right answers, " <>
          "and whether the last one was right. Weakest cards first.",
      input: %{}
    },
    %{
      name: "recent_history",
      description:
        "What the person did, newest first: answers (with what they answered and whether it was " <>
          "right), cards added/rewritten/burned, temperament changes, beckons, summoning.",
      input: %{
        "limit" => %{"type" => "integer", "description" => "how many (default 30, at most 200)"},
        "before" => %{"type" => "integer", "description" => "only entries older than this id (paging)"}
      }
    },
    %{
      name: "what_befell_my_being",
      description:
        "Events in the cosmos involving the person's being, newest first: meetings, gifts, " <>
          "quarrels, mourning, fading, revival, desire shifting.",
      input: %{"limit" => %{"type" => "integer", "description" => "how many (default 30)"}}
    },
    %{
      name: "cosmos_overview",
      description:
        "The cosmos at large: whether it is running, its tick, how many beings live and have " <>
          "faded, what the cosmos as a whole desires (the big Other), and recent public events.",
      input: %{}
    },
    %{
      name: "explain",
      description:
        "Explains a concept of the cosmos (ichor, grace, lack, objet a, registers, knot, symptom, " <>
          "desire, the big Other, temperament, boxes, the commons). Omit the topic for a list.",
      input: %{"topic" => %{"type" => "string"}}
    },
    %{
      name: "add_card",
      description:
        "Adds an incantation (flash card) to the being's deck. Leave back empty for a reminder " <>
          "that only needs acknowledging. At most 30 cards, 200 characters per side.",
      input: %{
        "front" => %{"type" => "string", "description" => "the question or prompt"},
        "back" => %{"type" => "string", "description" => "the answer (optional)"}
      },
      required: ["front"],
      writes: true
    },
    %{
      name: "rewrite_card",
      description:
        "Rewrites a card in the deck (its review progress starts over, back in box 1).",
      input: %{
        "card_id" => %{"type" => "string"},
        "front" => %{"type" => "string"},
        "back" => %{"type" => "string"}
      },
      required: ["card_id", "front"],
      writes: true
    },
    %{
      name: "burn_card",
      description: "Removes a card from the deck for good.",
      input: %{"card_id" => %{"type" => "string"}},
      required: ["card_id"],
      writes: true
    }
  ]

  @doc "The tools, as MCP tool definitions"
  def tools() do
    for t <- @tools do
      %{
        "name" => t.name,
        "description" => t.description,
        "inputSchema" => %{
          "type" => "object",
          "properties" => t.input,
          "required" => Map.get(t, :required, [])
        },
        "annotations" => %{
          "readOnlyHint" => not Map.get(t, :writes, false),
          "destructiveHint" => t.name == "burn_card"
        }
      }
    end
  end

  @doc """
  Runs a tool for `user` (the token's owner). `via` names the agent for the
  person's history. Returns `{:ok, result}` or `{:error, message}`.
  """
  def call(user, name, args \\ %{}, via \\ "agent")

  def call(user, "my_being", _args, _via), do: {:ok, being(user)}
  def call(user, "my_cards", _args, _via), do: {:ok, cards(user)}
  def call(user, "whispering_now", _args, _via), do: {:ok, whispering(user)}
  def call(user, "card_accuracy", _args, _via), do: {:ok, accuracy(user.id)}

  def call(user, "recent_history", args, _via) do
    limit = args |> Map.get("limit", 30) |> int(30) |> max(1) |> min(200)
    {:ok, History.interactions(user.id, limit: limit, before: int(args["before"], nil))}
  end

  def call(user, "what_befell_my_being", args, _via) do
    limit = args |> Map.get("limit", 30) |> int(30) |> max(1) |> min(200)

    case Owned.being_of(user.id) do
      nil -> {:ok, []}
      b -> {:ok, History.being_events(b["id"], limit)}
    end
  end

  def call(_user, "cosmos_overview", _args, _via), do: {:ok, overview()}
  def call(_user, "explain", args, _via), do: {:ok, explain(args["topic"])}

  def call(user, "add_card", args, via) do
    user.id |> Owned.add_card(args["front"], args["back"], via: via) |> written()
  end

  def call(user, "rewrite_card", args, via) do
    user.id |> Owned.update_card(args["card_id"], args["front"], args["back"], via: via) |> written()
  end

  def call(user, "burn_card", args, via) do
    user.id |> Owned.delete_card(args["card_id"], via: via) |> written()
  end

  def call(_user, name, _args, _via), do: {:error, "unknown tool #{inspect(name)}"}

  # ---------- what the tools return ----------

  def being(user) do
    case Owned.being_of(user.id) do
      nil ->
        nil

      vals ->
        vals
        |> Eldritch.World.being_view(user.id)
        |> Map.drop(["mine", "can_answer", "owner_id", "bonds"])
        |> Map.merge(%{
          "temperament" => Temperament.new(vals["temperament"] || %{}),
          "grace_left_ms" => Life.grace_left_ms(vals),
          "withering" => Life.condition(vals) != :vital,
          "bond_count" => map_size(vals["bonds"] || %{})
        })
    end
  end

  def cards(user) do
    case Owned.being_of(user.id) do
      nil ->
        []

      vals ->
        now = Eldritch.Clock.now_ms()

        for card <- Deck.cards(vals["deck"]) do
          card
          |> Map.take(~w(id front back box due_at awaiting streak recalls))
          |> Map.put("due_in_ms", max(0, card["due_at"] - now))
        end
    end
  end

  def whispering(user) do
    case Owned.being_of(user.id) do
      nil -> nil
      vals -> vals["deck"] |> Deck.awaiting() |> then(&(&1 && Map.take(&1, ~w(id front back box))))
    end
  end

  @doc "How well a person remembers each card they have answered, weakest first"
  def accuracy(owner) do
    owner
    |> History.interactions(limit: 5_000)
    |> Enum.filter(&(&1["kind"] == "answer"))
    |> Enum.group_by(& &1["data"]["card_id"])
    |> Enum.map(fn {card_id, answers} ->
      [latest | _] = answers

      %{
        "card_id" => card_id,
        "front" => latest["data"]["front"],
        "being" => latest["data"]["being"],
        "answers" => length(answers),
        "right" => Enum.count(answers, & &1["data"]["correct"]),
        "last_at" => latest["at"],
        "last_correct" => latest["data"]["correct"]
      }
    end)
    |> Enum.sort_by(&{&1["right"] / &1["answers"], -&1["last_at"]})
  end

  def overview() do
    world = Eldritch.World.snapshot(viewer: nil)

    %{
      "simulation" => Map.take(world["simulation"], ~w(running tick tick_ms population faded max_population)),
      "places" => length(world["nodes"]),
      "big_other" => world["big_other"],
      "recent_events" =>
        world["events"] |> Enum.take(25) |> Enum.map(&Map.take(&1, ~w(seq at kind text)))
    }
  end

  @glossary %{
    "ichor" => "A being's life force (0-200). It drains a little every tick; eating restores it. At 0 the being fades.",
    "grace" => "An owned being does not die of old age. Each answer its person gives buys 3 days of grace, during which it cannot starve. Unanswered longer, it withers and fades; one answer calls it back.",
    "lack" => "How acutely the being lacks (0-100). It grows over time, eases while the being gathers what it desires, and drops when it attains it, but never vanishes: desire is never satisfied.",
    "objet a" => "The being's hidden cause of desire: a resource it never desires directly. Holding too much of it brings anxiety and the being casts it away. Hidden until anxiety reveals it.",
    "registers" => "Real, Symbolic and Imaginary: three weights that sum to 1. Gifts raise the Symbolic, mirroring and rivalry the Imaginary, loss and starvation the Real.",
    "knot" => "When one register dominates (over 0.55) the knot loosens: an Imaginary being refuses every demand and quarrels harder, a Real one is ruled by repetition. It holds again below 0.47.",
    "symptom" => "After a bonded being fades, its mourners are drawn back to the place of loss until they have worked it through (three visits).",
    "desire" => "The resource a being currently longs for. Once it hoards enough it devours the hoard and desire slides to a new object, chosen from what the cosmos desires, what the being it mirrors desires, old desires returning, and what lies nearby.",
    "big other" => "What the cosmos as a whole desires and exchanges. Fads spread through it.",
    "temperament" => "The person's say in how the being lives (0-100, 50 is the commons' default): generosity, wanderlust, sociability and conformity bias its choices without dictating them.",
    "boxes" => "Leitner boxes 1-6 for each card: 20 seconds, 1 minute, 5 minutes, 30 minutes, 2 hours, 1 day until it is whispered again. A right answer moves a card up a box and feeds the being; a wrong one sends it back to box 1.",
    "commons" => "Beings nobody owns. They live 1 to 4 days; anyone signed in may answer their whispers. When fewer than 8 beings live, the cosmos dreams new ones."
  }

  def explain(nil), do: %{"topics" => Map.keys(@glossary)}
  def explain(""), do: explain(nil)

  def explain(topic) do
    key = topic |> to_string() |> String.downcase() |> String.trim()

    case Map.fetch(@glossary, key) do
      {:ok, text} -> %{"topic" => key, "explanation" => text}
      :error -> %{"topic" => key, "explanation" => nil, "topics" => Map.keys(@glossary)}
    end
  end

  # ---------- helpers ----------

  defp written({:ok, %{"id" => _} = card}), do: {:ok, Map.take(card, ~w(id front back box))}
  defp written({:ok, _}), do: {:ok, %{"ok" => true}}
  defp written({:error, :no_being}), do: {:error, "the person has no being yet"}
  defp written({:error, :no_card}), do: {:error, "no such card"}
  defp written({:error, :empty_front}), do: {:error, "a card needs a front"}
  defp written({:error, :too_long}), do: {:error, "card sides are at most 200 characters"}
  defp written({:error, :deck_full}), do: {:error, "the deck already holds 30 cards"}
  defp written({:error, other}), do: {:error, inspect(other)}

  defp int(v, _default) when is_integer(v), do: v

  defp int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> default
    end
  end

  defp int(_, default), do: default
end
