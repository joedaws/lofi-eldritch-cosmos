defmodule Eldritch.Being.Life do
  @moduledoc """
  How long beings live, measured in real (clock) time rather than ticks,
  so the cosmos keeps the pace of the people who visit it.

    * Beings of **the commons** age: each has a lifespan (1 to 4 days by
      default, `config :eldritch, :lifespan_ms`). Past it they wither.
    * **Owned beings** do not die of old age. They are sustained by their
      owner's remembering: answering any of their whispers keeps them vital
      for a grace period (3 days by default, `config :eldritch, :devotion_grace_ms`).
      Neglected longer, they wither, until an answer calls them back.

  Ages use `Eldritch.Clock`, so the replay recorder can compress time.
  """

  @day 24 * 60 * 60 * 1000

  def lifespan_range() do
    Application.get_env(:eldritch, :lifespan_ms, {1 * @day, 4 * @day})
  end

  def grace_ms(), do: Application.get_env(:eldritch, :devotion_grace_ms, 3 * @day)

  @doc "How long the husk of a faded commons being lingers before it crumbles"
  def husk_ms(), do: Application.get_env(:eldritch, :husk_ms, @day)

  @doc """
  Whether a faded being's husk has crumbled. Owned beings never crumble:
  their owner can always call them back.
  """
  def crumbled?(being_values) do
    faded_at = get_in(being_values, ["lineage", "faded_at"])

    get_in(being_values, ["ownership", "owner"]) == nil and
      being_values["status"] == "faded" and faded_at != nil and now() - faded_at > husk_ms()
  end

  def random_lifespan_ms() do
    {low, high} = lifespan_range()
    low + :rand.uniform(max(1, high - low))
  end

  def now(), do: Eldritch.Clock.now_ms()

  @doc """
  A lineage: generation, parents, when the being was born and how long it
  may live. `"age_fraction"` (0..1) backdates the birth, so a seeded cosmos
  is not one generation that ages out together.
  """
  def new_lineage(attrs \\ %{}) do
    lifespan = Map.get_lazy(attrs, "lifespan_ms", &random_lifespan_ms/0)
    backdate = round(lifespan * Map.get(attrs, "age_fraction", 0))

    %{
      "generation" => Map.get(attrs, "generation", 0),
      "parents" => Map.get(attrs, "parents", []),
      "born_at" => Map.get(attrs, "born_at", now() - backdate),
      "lifespan_ms" => lifespan
    }
  end

  @doc """
  Upgrades lineages from when age was counted in ticks: the old age becomes
  seconds already lived, and the being gets a lifespan on the new scale.
  """
  def normalize(nil), do: new_lineage()

  def normalize(%{"born_at" => _, "lifespan_ms" => _} = lineage), do: lineage

  def normalize(old) do
    new_lineage(%{
      "generation" => old["generation"] || 0,
      "parents" => old["parents"] || [],
      "born_at" => now() - 1000 * (old["age"] || 0)
    })
    |> Map.merge(Map.take(old, ["elder_noted"]))
  end

  def age_ms(lineage), do: max(0, now() - normalize(lineage)["born_at"])

  @doc """
  `:vital`, or `{:withering, :age}` for a commons being past its lifespan,
  or `{:withering, :neglect}` for an owned being whose owner has not
  answered it within the grace period.
  """
  def condition(being_values) do
    case get_in(being_values, ["ownership", "owner"]) do
      nil ->
        lineage = normalize(being_values["lineage"])
        if age_ms(lineage) > lineage["lifespan_ms"], do: {:withering, :age}, else: :vital

      _owner ->
        if neglect_ms(being_values) > 0, do: {:withering, :neglect}, else: :vital
    end
  end

  @doc "How long an owned being has gone unanswered past its grace (0 if none)"
  def neglect_ms(being_values) do
    last = last_answer_at(being_values)
    max(0, now() - last - grace_ms())
  end

  @doc "Milliseconds of grace left before an owned being begins to wither"
  def grace_left_ms(being_values) do
    max(0, last_answer_at(being_values) + grace_ms() - now())
  end

  defp last_answer_at(being_values) do
    get_in(being_values, ["ownership", "last_answer_at"]) ||
      normalize(being_values["lineage"])["born_at"]
  end

  @doc "Records that the owner answered: the grace period starts over"
  def remembered(being_server) do
    Cosmos.Entity.Server.update_component(being_server, "ownership", fn comp ->
      %{comp | value: comp.value |> Map.put("last_answer_at", now()) |> Map.delete("neglect_noted")}
    end)
  end
end
