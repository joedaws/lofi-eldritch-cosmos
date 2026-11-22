defmodule LofiWeb.ChannelCase do
  @moduledoc "Test case for channels (the page's live connection)."
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import LofiWeb.ChannelCase

      @endpoint LofiWeb.Endpoint
    end
  end

  setup tags do
    Lofi.DataCase.setup_sandbox(tags)
    :ok
  end
end
