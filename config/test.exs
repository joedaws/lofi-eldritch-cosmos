import Config

config :lofi, http_port: 5455

config :cosmos, monitor_metrics: "false"

# Keep test data far away from the real cosmos in the user data dir.
config :cosmos, data_dir_name: "lofi-eldritch-cosmos-test"

# Load persisted entities at boot? Tests manage their own entities.
config :eldritch, load_on_start: false

config :logger, level: :warning
