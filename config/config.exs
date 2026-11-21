# Configuration for every application in the umbrella. Environment
# specific settings live in dev.exs / test.exs / prod.exs, and settings
# read from the environment at boot (secrets, paths) in runtime.exs.
import Config

# ---------- cosmos: the entity component system ----------

config :cosmos, Cosmos.System.Scheduler,
  jobs: [
    # Every 1 minutes
    {"* * * * *", fn -> Cosmos.Metrics.get() end}
  ]

config :cosmos, monitor_metrics: "true"

# Name of the folder (inside $XDG_DATA_HOME) where the cosmos is persisted
config :cosmos, data_dir_name: "lofi-eldritch-cosmos"

# ---------- eldritch: the simulation ----------

# Simulation pacing: one "tick" is the base cycle duration (ms) every
# Eldritch system is scaled from. Lower is faster.
config :eldritch,
  tick_ms: 1000,
  # start every simulation system as soon as the application boots
  autostart: false,
  # load all persisted entities into memory when the application boots
  load_on_start: true,
  # how often an owner may beckon their being (ms)
  beckon_cooldown_ms: 60 * 60 * 1000

# ---------- lofi: accounts and the web ----------

config :lofi, :scopes,
  user: [
    default: true,
    module: Lofi.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Lofi.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :lofi,
  ecto_repos: [Lofi.Repo],
  generators: [timestamp_type: :utc_datetime]

config :lofi, LofiWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: 5454],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LofiWeb.ErrorHTML, json: LofiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Lofi.PubSub,
  live_view: [signing_salt: "Ux+sn0MC"]

config :phoenix_live_view, root_tag_attribute: "phx-r"

# Emails (login links, confirmations) are kept in memory in development
# and shown at /dev/mailbox. Production uses a real provider (runtime.exs).
config :lofi, Lofi.Mailer, adapter: Swoosh.Adapters.Local

config :phoenix, :json_library, Jason

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
