defmodule LofiWeb.UserSessionHTML do
  use LofiWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:lofi, Lofi.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
