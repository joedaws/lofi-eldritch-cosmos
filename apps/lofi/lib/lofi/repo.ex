defmodule Lofi.Repo do
  use Ecto.Repo,
    otp_app: :lofi,
    adapter: Ecto.Adapters.SQLite3
end
