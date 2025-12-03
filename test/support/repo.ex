defmodule Polyjuice.Repo do
  use Ecto.Repo,
    otp_app: :polyjuice,
    adapter: Ecto.Adapters.SQLite3
end
