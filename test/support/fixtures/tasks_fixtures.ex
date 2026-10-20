defmodule MiniTask.TasksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MiniTask.Tasks` context.
  """

  alias MiniTask.Tasks

  import MiniTask.AccountsFixtures

  def task_fixture(attrs \\ %{}) do
    task_fixture(user_scope_fixture(), attrs)
  end

  def task_fixture(scope, attrs) do
    attrs = Enum.into(attrs, %{title: "Task #{System.unique_integer([:positive])}"})

    {:ok, task} = Tasks.create_task(scope, attrs)
    task
  end
end
