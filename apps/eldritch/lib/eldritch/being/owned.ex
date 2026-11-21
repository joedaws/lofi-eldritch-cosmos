defmodule Eldritch.Being.Owned do
  @moduledoc """
  Beings that belong to people.

  Every person may summon exactly one being into the shared cosmos. They
  shape it through its temperament (`Eldritch.Being.Temperament`) and its
  deck of incantations (`Eldritch.Being.Deck`), and may beckon it to a
  place now and then (once per `config :eldritch, :beckon_cooldown_ms`).
  Only the owner can answer its whispers, so their remembering is what
  keeps it alive.

  Owners are identified by an opaque id (the account id in `Lofi`);
  Eldritch knows nothing else about people.
  """
  alias Eldritch.Being
  alias Eldritch.Being.{Deck, Temperament}
  alias Eldritch.Entities

  @max_name 32

  @doc "The values of the being owned by `owner`, or nil"
  def being_of(nil), do: nil

  def being_of(owner) do
    Entities.being_list() |> Enum.find(&(Being.owner(&1) == owner))
  end

  @doc """
  Summons the owner's being. Attributes (all optional): `"name"`,
  `"at_node"`, `"cards"` (`[%{"front", "back"}]`), `"temperament"`.
  `"owner_name"` is only used for the chronicle.
  """
  def summon(owner, attrs) when not is_nil(owner) do
    nodes = Eldritch.query("nodes")["node_ids"]

    with :ok <- if(being_of(owner), do: {:error, :already_has_being}, else: :ok),
         :ok <- if(nodes == [], do: {:error, :no_places}, else: :ok),
         {:ok, name} <- name(attrs["name"]),
         {:ok, at_node} <- place(attrs["at_node"], nodes),
         {:ok, cards} <- cards(attrs["cards"]) do
      id =
        Being.Builder.build({:new, :being, :standard}, %{
          "name" => name,
          "at_node" => at_node,
          "owner" => owner,
          "deck" => cards,
          "temperament" => Temperament.new(attrs["temperament"] || %{}),
          "ichor" => 120
        })

      node_name = Cosmos.Entity.Cache.server_process(at_node) |> Cosmos.Entity.Server.value("name")
      by = if attrs["owner_name"], do: " by #{attrs["owner_name"]}", else: ""

      Eldritch.Chronicle.record(:summon, "#{name} is summoned into #{node_name}#{by}.", %{
        "beings" => [id],
        "node" => at_node
      })

      {:ok, id}
    end
  end

  def set_temperament(owner, changes) do
    with_being(owner, fn vals, pid ->
      Cosmos.Entity.Server.update_component(pid, "temperament", fn comp ->
        %{comp | value: Temperament.update(comp.value, changes)}
      end)

      {:ok, Temperament.update(vals["temperament"], changes)}
    end)
  end

  def add_card(owner, front, back) do
    change_deck(owner, &Deck.add(&1, front, back))
  end

  def update_card(owner, card_id, front, back) do
    change_deck(owner, &Deck.update(&1, card_id, front, back))
  end

  def delete_card(owner, card_id) do
    change_deck(owner, &Deck.delete(&1, card_id))
  end

  @doc """
  Beckons the owner's being to a place, at most once per cooldown.
  Returns `:ok`, `{:error, {:cooldown, ms_left}}` or another error.
  """
  def beckon(owner, node_id) do
    with_being(owner, fn vals, pid ->
      last = get_in(vals, ["ownership", "beckoned_at"])
      left = if last, do: last + cooldown() - now(), else: 0

      if left > 0 do
        {:error, {:cooldown, left}}
      else
        with :ok <- Being.beckon(vals["id"], node_id) do
          Cosmos.Entity.Server.update_component(pid, "ownership", fn comp ->
            %{comp | value: Map.put(comp.value, "beckoned_at", now())}
          end)

          :ok
        end
      end
    end)
  end

  @doc "Milliseconds until the owner's being may be beckoned again (0 = now)"
  def beckon_wait(vals) do
    case get_in(vals, ["ownership", "beckoned_at"]) do
      nil -> 0
      last -> max(0, last + cooldown() - now())
    end
  end

  def cooldown(), do: Application.get_env(:eldritch, :beckon_cooldown_ms, 3_600_000)

  # ---------- helpers ----------

  defp change_deck(owner, fun) do
    with_being(owner, fn _vals, pid ->
      Cosmos.Entity.Server.get_and_update_component(pid, "deck", fn comp ->
        case fun.(comp.value) do
          {:ok, deck, card} -> {{:ok, card}, %{comp | value: deck}}
          {:ok, deck} -> {{:ok, deck}, %{comp | value: deck}}
          error -> {error, comp}
        end
      end)
    end)
  end

  defp with_being(owner, fun) do
    case being_of(owner) do
      nil -> {:error, :no_being}
      vals -> fun.(vals, vals["pid"])
    end
  end

  defp name(nil), do: {:ok, Eldritch.Being.NameGenerator.next()}
  defp name(""), do: name(nil)

  defp name(name) when is_binary(name) do
    name = String.trim(name)

    cond do
      name == "" -> name(nil)
      String.length(name) > @max_name -> {:error, :name_too_long}
      true -> {:ok, name}
    end
  end

  defp name(_), do: {:error, :bad_name}

  defp place(nil, nodes), do: {:ok, Enum.random(nodes)}
  defp place("", nodes), do: place(nil, nodes)
  defp place(id, nodes), do: if(id in nodes, do: {:ok, id}, else: {:error, :unknown_node})

  defp cards(nil), do: {:ok, [Eldritch.Being.Incantation.default()]}
  defp cards([]), do: cards(nil)

  defp cards(cards) when is_list(cards) do
    deck =
      Enum.reduce_while(cards, {:ok, Deck.new()}, fn card, {:ok, deck} ->
        case Deck.add(deck, card["front"], card["back"]) do
          {:ok, deck, _} -> {:cont, {:ok, deck}}
          error -> {:halt, error}
        end
      end)

    with {:ok, deck} <- deck, do: {:ok, Deck.cards(deck)}
  end

  defp cards(_), do: {:error, :bad_cards}

  defp now(), do: System.system_time(:millisecond)
end
