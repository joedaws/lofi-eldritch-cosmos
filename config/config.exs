# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :cosmos, Cosmos.System.Scheduler,
  jobs: [
    # Every 1 minutes
    {"* * * * *", fn -> Cosmos.Metrics.get() end}
  ]

config :lofi, http_port: 5454

config :cosmos, monitor_metrics: "true"

# Name of the folder (inside $XDG_DATA_HOME) where entities are persisted
config :cosmos, data_dir_name: "lofi-eldritch-cosmos"

# Simulation pacing: one "tick" is the base cycle duration (ms) every
# Eldritch system is scaled from. Lower is faster.
config :eldritch,
  tick_ms: 1000,
  # start every simulation system as soon as the application boots
  autostart: false,
  # load all persisted entities into memory when the application boots
  load_on_start: true

config :logger, :console, format: "$time [$level] $message\n"

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#
#
import_config "#{Mix.env()}.exs"
