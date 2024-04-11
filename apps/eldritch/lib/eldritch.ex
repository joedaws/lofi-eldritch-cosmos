defmodule Eldritch do

  @doc """

  filters
  "beings" --> Return list of all beings for the current user
  """

  @doc """
  Passes along the search filter from the the Lofi application to
  the Cosmos Application.

  Changes to how the filter is used are made here, not in the Lofi application.
  That way users of lofi don't need to worry if Cosmos database changes.
  """
  def query(filter) do
    Cosmos.query(filter)
  end
end
