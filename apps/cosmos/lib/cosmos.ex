defmodule Cosmos do
  @moduledoc """
  Entry point for the `Cosmos` entity component system.
  """

  def get_persist_dir() do
    Application.fetch_env!(:cosmos, :local_db_dir)
  end

  @doc """
  Query the database.

  Supported filters:
    * `"entities"` - `%{"entity_ids" => [...]}` every persisted entity id
    * `"beings"`   - `%{"being_ids" => [...]}` ids of persisted entities that are beings
  """
  def query(filter) do
    Cosmos.Database.query(filter)
  end
end
