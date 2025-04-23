defmodule Survey.Repo do
  use Ecto.Repo,
    otp_app: :survey,
    adapter: Ecto.Adapters.Postgres
end
