defmodule MiniTask.Repo.Migrations.CreateTaskTables do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :title, :string, null: false
      add :description, :text, null: true
      add :status, :string, null: false, default: "pending"
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:user_id, :status])

    create constraint(:tasks, :status_valid,
             check: "status IN ('pending', 'in_progress', 'done', 'cancelled')"
           )

    create table(:task_assignments) do
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:task_assignments, [:task_id, :user_id])
    create index(:task_assignments, [:user_id])
  end
end
