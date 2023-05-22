import Config

config :lofi, http_port: 5455

config :cosmos, local_db_dir: "./.data/persist-test"

config :cosmos, monitor_metrics: "false"
