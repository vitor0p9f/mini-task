defmodule MiniTask.Repo do
  use Ecto.Repo,
    otp_app: :mini_task,
    adapter: Ecto.Adapters.Postgres
end
