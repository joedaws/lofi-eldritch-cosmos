defmodule Cosmos do
  @moduledoc """
  Documentation for `Cosmos`.
  """

  def get_persist_dir() do
    Application.fetch_env!(:cosmos, :local_db_dir)
  end

  @doc """
  The Database query should return some kind of map
  object or list object.
  """
  def query(filter) do
    result = Cosmos.Database.query(filter)
  end
end
