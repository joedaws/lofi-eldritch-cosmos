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
    # nginx in front terminates https; the app only listens on localhost
    http: [ip: {127, 0, 0, 1}],
    secret_key_base: secret_key_base

  # Login links are emailed through Resend (https://resend.com)
  if api_key = System.get_env("RESEND_API_KEY") do
    config :lofi, Lofi.Mailer, adapter: Swoosh.Adapters.Resend, api_key: api_key
  else
    IO.warn("RESEND_API_KEY is not set: login emails cannot be sent")
  end

  # the address login emails come from, e.g. "Lofi Eldritch Cosmos <login@your-domain>"
  if from = System.get_env("MAIL_FROM") do
    case Regex.run(~r/^\s*(.*?)\s*<([^>]+)>\s*$/, from) do
      [_, name, address] -> config :lofi, mail_from: {name, address}
      _ -> config :lofi, mail_from: {"Lofi Eldritch Cosmos", String.trim(from)}
    end
  end
end
