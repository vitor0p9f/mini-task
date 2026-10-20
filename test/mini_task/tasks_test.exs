defmodule MiniTask.TasksTest do
  use MiniTask.DataCase

  alias MiniTask.Tasks
  alias MiniTask.Tasks.Task

  import MiniTask.AccountsFixtures
  import MiniTask.TasksFixtures

  describe "create_task/2" do
    test "creates a task owned by the scoped user" do
      scope = user_scope_fixture()

      assert {:ok, %Task{} = task} =
               Tasks.create_task(scope, %{title: "Write tests", description: "Cover the context"})

      assert task.title == "Write tests"
      assert task.description == "Cover the context"
      assert task.status == :pending
      assert task.user_id == scope.user.id
      assert Repo.get!(Task, task.id).user_id == scope.user.id
    end

    test "requires a title" do
      scope = user_scope_fixture()

      assert {:error, changeset} = Tasks.create_task(scope, %{})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "list_tasks/1" do
    test "lists tasks created by the user" do
      scope = user_scope_fixture()
      task = task_fixture(scope, %{title: "Mine"})

      assert [%Task{id: id}] = Tasks.list_tasks(scope)
      assert id == task.id
    end

    test "lists tasks assigned to the user" do
      owner = user_fixture()
      assignee = user_fixture()
      owner_scope = user_scope_fixture(owner)

      task = task_fixture(owner_scope, %{title: "Assigned"})
      assert {:ok, _task} = Tasks.assign_users(owner_scope, task, [assignee.id])

      assert [%Task{id: id}] = Tasks.list_tasks(user_scope_fixture(assignee))
      assert id == task.id
    end

    test "does not list tasks from other users" do
      _task = task_fixture(%{title: "Not mine"})

      assert Tasks.list_tasks(user_scope_fixture()) == []
    end

    test "does not duplicate a task when the user is creator and assignee" do
      scope = user_scope_fixture()
      task = task_fixture(scope, %{title: "Mine twice"})

      assert {:ok, _task} = Tasks.assign_users(scope, task, [scope.user.id])

      assert [%Task{id: id}] = Tasks.list_tasks(scope)
      assert id == task.id
    end
  end

  describe "get_task!/2" do
    test "returns a task created by the user" do
      scope = user_scope_fixture()
      task = task_fixture(scope, %{title: "Visible"})

      assert %Task{id: id, assignees: []} = Tasks.get_task!(scope, task.id)
      assert id == task.id
    end

    test "returns a task assigned to the user" do
      owner = user_fixture()
      assignee = user_fixture()
      owner_scope = user_scope_fixture(owner)

      task = task_fixture(owner_scope, %{title: "Assigned"})
      assert {:ok, _task} = Tasks.assign_users(owner_scope, task, [assignee.id])

      assert %Task{id: id} = Tasks.get_task!(user_scope_fixture(assignee), task.id)
      assert id == task.id
    end

    test "raises when the task is not visible to the user" do
      task = task_fixture(%{title: "Private"})
      scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Tasks.get_task!(scope, task.id)
      end
    end
  end

  describe "update_task/3" do
    test "updates a task owned by the user" do
      scope = user_scope_fixture()
      task = task_fixture(scope, %{title: "Before"})

      assert {:ok, %Task{} = updated} =
               Tasks.update_task(scope, task, %{title: "After", status: "done"})

      assert updated.title == "After"
      assert updated.status == :done
    end

    test "raises when the user does not own the task" do
      task = task_fixture(%{title: "Someone else's"})
      scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Tasks.update_task(scope, task, %{title: "Nope"})
      end
    end

    test "raises when the user is only an assignee" do
      owner = user_fixture()
      assignee = user_fixture()
      owner_scope = user_scope_fixture(owner)

      task = task_fixture(owner_scope, %{title: "Owner only"})
      assert {:ok, _task} = Tasks.assign_users(owner_scope, task, [assignee.id])

      assert_raise Ecto.NoResultsError, fn ->
        Tasks.update_task(user_scope_fixture(assignee), task, %{title: "Nope"})
      end
    end
  end

  describe "delete_task/2" do
    test "deletes a task owned by the user" do
      scope = user_scope_fixture()
      task = task_fixture(scope, %{title: "Delete me"})

      assert {:ok, %Task{}} = Tasks.delete_task(scope, task)
      refute Repo.get(Task, task.id)
    end

    test "raises when the user does not own the task" do
      task = task_fixture(%{title: "Not yours"})
      scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Tasks.delete_task(scope, task)
      end
    end
  end

  describe "assign_users/3" do
    test "assigns multiple users to a task" do
      owner = user_fixture()
      assignee_one = user_fixture()
      assignee_two = user_fixture()
      scope = user_scope_fixture(owner)
      task = task_fixture(scope, %{title: "Assign me"})

      assert {:ok, %Task{assignees: assignees}} =
               Tasks.assign_users(scope, task, [assignee_one.id, assignee_two.id])

      assert Enum.sort(Enum.map(assignees, & &1.id)) ==
               Enum.sort([assignee_one.id, assignee_two.id])
    end

    test "replaces the existing assignments" do
      owner = user_fixture()
      assignee_one = user_fixture()
      assignee_two = user_fixture()
      assignee_three = user_fixture()
      scope = user_scope_fixture(owner)
      task = task_fixture(scope, %{title: "Reassign me"})

      assert {:ok, _task} =
               Tasks.assign_users(scope, task, [assignee_one.id, assignee_two.id])

      assert {:ok, %Task{assignees: assignees}} =
               Tasks.assign_users(scope, task, [assignee_two.id, assignee_three.id])

      assert Enum.sort(Enum.map(assignees, & &1.id)) ==
               Enum.sort([assignee_two.id, assignee_three.id])
    end

    test "clears all assignments when given an empty list" do
      owner = user_fixture()
      assignee = user_fixture()
      scope = user_scope_fixture(owner)
      task = task_fixture(scope, %{title: "Clear me"})

      assert {:ok, _task} = Tasks.assign_users(scope, task, [assignee.id])

      assert {:ok, %Task{assignees: []}} = Tasks.assign_users(scope, task, [])
    end

    test "returns an error when a user does not exist" do
      scope = user_scope_fixture()
      task = task_fixture(scope, %{title: "Unknown assignee"})

      assert {:error, :unknown_users} = Tasks.assign_users(scope, task, [-1])
    end

    test "raises when the user does not own the task" do
      task = task_fixture(%{title: "Not yours"})
      scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Tasks.assign_users(scope, task, [scope.user.id])
      end
    end
  end
end
