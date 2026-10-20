defmodule MiniTask.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :title, :string
    field :description, :string

    field :status, Ecto.Enum,
      values: [:pending, :in_progress, :done, :cancelled],
      default: :pending

    belongs_to :user, MiniTask.Accounts.User
    has_many :assignments, MiniTask.Tasks.TaskAssignment
    has_many :assignees, through: [:assignments, :user]

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:title, :description, :status])
    |> validate_required([:title])
    |> check_constraint(:status, name: :status_valid)
  end
end
