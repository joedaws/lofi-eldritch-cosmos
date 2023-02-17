import Config

config :cosmos,
  data_path: System.get_env("COSMOS_DATA_PATH"),
  local_db_dir: System.get_env("COSMOS_LOCAL_DB_DIR")
