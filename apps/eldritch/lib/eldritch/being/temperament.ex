defmodule Eldritch.Being.Temperament do
  @moduledoc """
  An owner's say in how their being lives. Each trait is 0..100; 50 is the
  temperament of the commons and leaves behaviour exactly as it would be
  without one. Traits bias choices; they never dictate them.

    * `"generosity"`  - how readily the being answers demands, and with how
                        much (50: always gives 3; 0: never gives; 100: gives 6)
    * `"wanderlust"`  - above 50 it sometimes leaves the place its desire
                        grows to explore; below 50 it sometimes stays put
                        instead of wandering
    * `"sociability"` - how strongly it is drawn to bonded beings next door
                        (50: 35% a tick; 100: 70%; 0: never)
    * `"conformity"`  - how much its next desire follows the big Other (what
                        the cosmos desires) rather than its own chain
  """

  @traits ["generosity", "wanderlust", "sociability", "conformity"]

  def traits(), do: @traits

  @doc "A full temperament; unknown keys are dropped, values clamped to 0..100"
  def new(attrs \\ %{}) do
    Map.new(@traits, fn t -> {t, attrs |> Map.get(t, 50) |> clamp()} end)
  end

  @doc "Merges valid trait changes into a temperament"
  def update(temperament, changes) when is_map(changes) do
    new(Map.merge(new(temperament || %{}), Map.take(changes, @traits)))
  end

  @doc "The trait of a being's values (50 when it has no temperament)"
  def trait(being_values, trait) when trait in @traits do
    get_in(being_values, ["temperament", trait]) || 50
  end

  # 0 -> 0, 50 -> 1, 100 -> 2: scales a behaviour around the commons default
  def factor(being_values, trait), do: trait(being_values, trait) / 50

  defp clamp(v) when is_number(v), do: v |> round() |> max(0) |> min(100)

  defp clamp(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> clamp(n)
      :error -> 50
    end
  end

  defp clamp(_), do: 50
end
