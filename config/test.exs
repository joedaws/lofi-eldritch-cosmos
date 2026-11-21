import Config

config :cosmos, monitor_metrics: "false"

# Keep test data far away from the real cosmos in the user data dir.
config :cosmos, data_dir_name: "lofi-eldritch-cosmos-test"

# Tests manage their own entities.
config :eldritch, load_on_start: false

# Only one hash round to speed up the test suite
config :bcrypt_elixir, :log_rounds, 1

config :lofi, Lofi.Repo, pool_size: 5, pool: Ecto.Adapters.SQL.Sandbox

# the test alias runs migrations itself
config :lofi, migrate_on_start: false

config :lofi, LofiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "EVX2ltO/oq8HRAih1ufWrhcRxw20tOBzOmrbS5Io2UNb9ohMa9GvCtLNb78irQDJ",
  server: false

config :lofi, Lofi.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view, enable_expensive_runtime_checks: true
config :phoenix, sort_verified_routes_query_params: true
