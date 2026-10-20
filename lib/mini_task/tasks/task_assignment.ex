defmodule MiniTask.Tasks.TaskAssignment do
  use Ecto.Schema

  schema "task_assignments" do
    belongs_to :task, MiniTask.Tasks.Task
    belongs_to :user, MiniTask.Accounts.User

    timestamps(type: :utc_datetime)
  end
end
