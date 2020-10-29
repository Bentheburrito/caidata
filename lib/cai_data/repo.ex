defmodule CAIData.Repo do
  use Ecto.Repo,
    otp_app: :caidata,
    adapter: Ecto.Adapters.Postgres
end
