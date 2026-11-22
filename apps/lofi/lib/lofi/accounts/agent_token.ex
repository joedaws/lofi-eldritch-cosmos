defmodule Lofi.Accounts.AgentToken do
  @moduledoc """
  A token a person gives their own learning agent, so it can see their
  being, its deck and their history, and edit the deck (see `Lofi.Agent`).

  The token itself (`lofi_agent_…`) is shown once when created; only its
  SHA-256 hash is stored. Revoked tokens stop working immediately.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @prefix "lofi_agent_"

  schema "agent_tokens" do
    field :name, :string
    field :token_hash, :binary, redact: true
    field :last_used_at, :utc_datetime
    field :revoked_at, :utc_datetime
    belongs_to :user, Lofi.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "A new token: `{plain_token, changeset}`"
  def build(user, name) do
    plain = @prefix <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    changeset =
      %__MODULE__{user_id: user.id, token_hash: hash(plain)}
      |> cast(%{name: name}, [:name])
      |> update_change(:name, &String.trim/1)
      |> validate_required([:name])
      |> validate_length(:name, max: 40)

    {plain, changeset}
  end

  def hash(plain) when is_binary(plain), do: :crypto.hash(:sha256, plain)

  def prefix(), do: @prefix
end
