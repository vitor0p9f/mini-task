defmodule MiniTask.Tasks do
  import Ecto.Query, warn: false

  alias MiniTask.Repo
  alias MiniTask.Accounts
  alias MiniTask.Accounts.Scope
  alias MiniTask.Tasks.{Task, TaskAssignment}

  # Read
  def list_tasks(%Scope{user: %{id: user_id}}) do
    Task
    |> visible_to(user_id)
    |> preload(:assignees)
    |> order_by([task], desc: task.inserted_at)
    |> Repo.all()
  end

  def list_assignable_users do
    Accounts.User
    |> order_by([user], asc: user.email)
    |> Repo.all()
  end

  def get_task!(%Scope{user: %{id: user_id}}, task_id) do
    Task
    |> visible_to(user_id)
    |> where([task], task.id == ^task_id)
    |> preload(:assignees)
    |> Repo.one!()
  end

  # Write
  def create_task(%Scope{user: %{id: user_id}}, attrs) do
    %Task{user_id: user_id}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  def update_task(%Scope{user: %{id: user_id}}, %Task{} = task, attrs) do
    authorize_owner!(user_id, task)

    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  def delete_task(%Scope{user: %{id: user_id}}, %Task{} = task) do
    authorize_owner!(user_id, task)

    Repo.delete(task)
  end

  def assign_users(%Scope{user: %{id: user_id}}, %Task{} = task, user_ids) do
    authorize_owner!(user_id, task)

    user_ids =
      user_ids |> List.wrap() |> Enum.map(&to_id/1) |> Enum.uniq() |> Enum.reject(&is_nil/1)

    users = Repo.all(from user in Accounts.User, where: user.id in ^user_ids)

    if length(users) != length(user_ids) do
      {:error, :unknown_users}
    else
      replace_assignments(task, users)
    end
  end

  # Helpers
  def visible?(%Scope{user: %{id: user_id}}, %Task{id: task_id}) do
    Task
    |> visible_to(user_id)
    |> where([task], task.id == ^task_id)
    |> Repo.exists?()
  end

  defp visible_to(query, user_id) do
    from task in query,
      left_join: assignment in assoc(task, :assignments),
      where: task.user_id == ^user_id or assignment.user_id == ^user_id,
      distinct: true
  end

  defp authorize_owner!(user_id, %Task{user_id: user_id}), do: :ok
  defp authorize_owner!(_user, _task), do: raise(Ecto.NoResultsError, queryable: Task)

  defp to_id(id) when is_integer(id), do: id
  defp to_id(""), do: nil
  defp to_id(id) when is_binary(id), do: String.to_integer(id)

  defp replace_assignments(%Task{} = task, users) when is_list(users) do
    now = DateTime.utc_now(:second)
    user_ids = Enum.map(users, & &1.id)

    Repo.transact(fn ->
      delete_removed_assignments(task.id, user_ids)

      entries =
        Enum.map(user_ids, fn user_id ->
          %{task_id: task.id, user_id: user_id, inserted_at: now, updated_at: now}
        end)

      Repo.insert_all(TaskAssignment, entries,
        on_conflict: :nothing,
        conflict_target: [:task_id, :user_id]
      )

      {:ok, Repo.preload(task, :assignees, force: true)}
    end)
  end

  defp delete_removed_assignments(task_id, []) do
    Repo.delete_all(
      from assignment in TaskAssignment,
        where: assignment.task_id == ^task_id
    )
  end

  defp delete_removed_assignments(task_id, user_ids) do
    Repo.delete_all(
      from assignment in TaskAssignment,
        where: assignment.task_id == ^task_id and assignment.user_id not in ^user_ids
    )
  end
end
