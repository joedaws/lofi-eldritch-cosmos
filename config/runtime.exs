import Config

# The accounts database lives next to the cosmos database, in
# $XDG_DATA_HOME/<data dir> (usually ~/.local/share/lofi-eldritch-cosmos).
data_dir =
  Path.join(
    System.get_env("XDG_DATA_HOME") || Path.join(System.user_home!(), ".local/share"),
    if(config_env() == :test, do: "lofi-eldritch-cosmos-test", else: "lofi-eldritch-cosmos")
  )

File.mkdir_p!(data_dir)

config :lofi, Lofi.Repo,
  database: System.get_env("DATABASE_PATH") || Path.join(data_dir, "accounts.sqlite3")

if System.get_env("PHX_SERVER") do
  config :lofi, LofiWeb.Endpoint, server: true
end

if port = System.get_env("PORT") do
  config :lofi, LofiWeb.Endpoint, http: [port: String.to_integer(port)]
end

if config_env() == :dev do
  config :lofi, LofiWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        ~r"apps/lofi/priv/static/.*\.(js|css|png|jpeg|jpg|gif|svg|html)$",
        ~r"apps/lofi/lib/lofi_web/(controllers|components)/.*\.(ex|heex)$"
      ]
    ]
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :lofi, LofiWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base

  # Emails (login links) need a real provider in production, e.g.
  #   config :lofi, Lofi.Mailer, adapter: Swoosh.Adapters.Postmark, api_key: System.get_env("POSTMARK_API_KEY")
end
