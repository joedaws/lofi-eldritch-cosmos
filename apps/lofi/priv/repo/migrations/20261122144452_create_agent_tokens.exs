defmodule Lofi.Repo.Migrations.CreateAgentTokens do
  use Ecto.Migration

  # tokens people give their learning agents; only a hash of each is kept
  def change do
    create table(:agent_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :token_hash, :binary, null: false
      add :last_used_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:agent_tokens, [:user_id])
    create unique_index(:agent_tokens, [:token_hash])
  end
end
