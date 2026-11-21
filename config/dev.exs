import Config

config :lofi, Lofi.Repo,
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# `mix run --no-halt` and `mix phx.server` both serve http://localhost:5454
config :lofi, LofiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  server: true,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "CaS/RT5yeYaa9CqzIe6OO7qMcB9jEgP1k+lHYiUumj0OmY/6mmvoVFNqeI+GsWK7",
  watchers: []

# Enable /dev/mailbox
config :lofi, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

config :swoosh, :api_client, false
