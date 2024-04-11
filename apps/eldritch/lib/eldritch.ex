defmodule Eldritch do

  @doc """

  filters
  "beings" --> Return list of all beings for the current user
  """

  def query(filter) do
    Cosmos.query(filter)
    |> Enum.join(", ")
  end
end
