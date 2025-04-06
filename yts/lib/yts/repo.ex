defmodule Yts.Repo do
  use Ecto.Repo,
    otp_app: :yts,
    adapter: Ecto.Adapters.SQLite3
end
