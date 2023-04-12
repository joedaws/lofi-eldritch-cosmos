hostname = "aws.connect.psdb.cloud"

{:ok, pid} =
  MyXQL.start_link(
    username: "nhcadqgf06dz3b6v156q",
    database: "lofi-eldritch-cosmos",
    hostname: hostname,
    password: System.get_env("DATABASE_PASSWORD"),
    ssl: true,
    ssl_opts: [
      verify: :verify_peer,
      cacertfile: CAStore.file_path(),
      server_name_indication: String.to_charlist(hostname),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  )
