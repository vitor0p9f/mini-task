defmodule MiniTaskWeb.TaskLive.Index do
  use MiniTaskWeb, :live_view

  alias MiniTask.Tasks

  @avatar_colors ~w(bg-rose-500 bg-sky-600 bg-emerald-600 bg-violet-600 bg-cyan-600 bg-indigo-600 bg-fuchsia-600 bg-teal-600)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      MiniTaskWeb.Endpoint.subscribe("tasks")
    end

    tasks = Tasks.list_tasks(socket.assigns.current_scope)

    users =
      Tasks.list_assignable_users()
      |> Enum.reject(fn user ->
        user.id == socket.assigns.current_scope.user.id
      end)

    {:ok,
     socket
     |> assign(:task_count, length(tasks))
     |> assign(:users, users)
     |> assign(:show_task_modal, false)
     |> assign(:editing_task, nil)
     |> assign(:form, task_form())
     |> stream(:tasks, tasks)}
  end

  @impl true
  def handle_event("open_task_modal", _payload, socket) do
    {:noreply, socket |> assign(:show_task_modal, true) |> assign(:editing_task, nil)}
  end

  @impl true
  def handle_event("close_task_modal", _payload, socket) do
    {:noreply, socket |> assign(:show_task_modal, false) |> assign(:form, task_form())}
  end

  @impl true
  def handle_event("edit_task", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    task = Tasks.get_task!(scope, String.to_integer(id))

    if task.user_id == scope.user.id do
      {:noreply,
       socket
       |> assign(:editing_task, task)
       |> assign(
         :form,
         to_form(
           %{
             "title" => task.title,
             "description" => task.description,
             "status" => task.status
           },
           as: :task
         )
       )
       |> assign(:show_task_modal, true)}
    else
      {:noreply, put_flash(socket, :error, "You cannot edit this task")}
    end
  end

  @impl true
  def handle_event("save_task", %{"task" => task_params}, socket) do
    scope = socket.assigns.current_scope
    asignee_ids = Map.get(task_params, "assignee_ids", [])
    task_params = Map.drop(task_params, ["assignee_ids"])

    case socket.assigns.editing_task do
      nil ->
        with {:ok, task} <- Tasks.create_task(scope, task_params),
             {:ok, task} <- Tasks.assign_users(scope, task, asignee_ids) do
          MiniTaskWeb.Endpoint.broadcast_from(
            self(),
            "tasks",
            "task_created",
            %{}
          )

          {:noreply,
           socket
           |> assign(:show_task_modal, false)
           |> assign(:editing_task, nil)
           |> assign(:form, task_form())
           |> refresh_tasks()}
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}

          {:error, :unknown_users} ->
            {:noreply, put_flash(socket, :error, "Invalid assignee!")}
        end

      task ->
        with {:ok, task} <- Tasks.update_task(scope, task, task_params),
             {:ok, task} <- Tasks.assign_users(scope, task, asignee_ids) do
          MiniTaskWeb.Endpoint.broadcast_from(
            self(),
            "tasks",
            "task_updated",
            %{}
          )

          {:noreply,
           socket
           |> assign(:show_task_modal, false)
           |> assign(:editing_task, nil)
           |> assign(:form, task_form())
           |> refresh_tasks()}
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}

          {:error, :unknown_users} ->
            {:noreply, put_flash(socket, :error, "Invalid assignee!")}
        end
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    task = Tasks.get_task!(scope, String.to_integer(id))

    if task.user_id == scope.user.id do
      {:ok, _task} = Tasks.delete_task(scope, task)

      MiniTaskWeb.Endpoint.broadcast_from(
        self(),
        "tasks",
        "task_deleted",
        %{}
      )

      {:noreply,
       socket
       |> assign(:task_count, socket.assigns.task_count - 1)
       |> put_flash(:info, "Task deleted!")
       |> refresh_tasks()}
    else
      {:noreply, socket |> put_flash(:error, "You cannot delete this task")}
    end
  end

  defp refresh_tasks(socket) do
    tasks = Tasks.list_tasks(socket.assigns.current_scope)

    socket
    |> assign(:task_count, length(tasks))
    |> stream(:tasks, tasks, reset: true)
  end

  @impl true
  def handle_info(%{event: event}, socket)
      when event in ["task_created", "task_updated", "task_deleted"] do
    {:noreply, refresh_tasks(socket)}
  end

  attr :user, :map, required: true
  attr :size, :string, default: "size-8"
  attr :class, :any, default: nil

  def user_avatar(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex shrink-0 items-center justify-center rounded-full text-xs font-semibold text-white ring-2 ring-base-100",
        @size,
        avatar_color(@user.email),
        @class
      ]}
      title={@user.email}
      aria-hidden="true"
    >
      {user_initial(@user.email)}
    </span>
    """
  end

  defp avatar_color(email) do
    Enum.at(@avatar_colors, :erlang.phash2(email, length(@avatar_colors)))
  end

  defp user_initial(email) do
    email |> String.first() |> String.upcase()
  end

  defp status_label(status) do
    status
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp status_badge(:pending), do: "badge-warning"
  defp status_badge(:in_progress), do: "badge-info"
  defp status_badge(:done), do: "badge-success"
  defp status_badge(:cancelled), do: "badge-ghost"

  defp assignee_names(assignees) do
    Enum.map_join(assignees, ", ", & &1.email)
  end

  defp row_item({_id, task}), do: task

  defp task_form(attrs \\ %{}) do
    to_form(Map.merge(%{"title" => "", "description" => "", "status" => "pending"}, attrs),
      as: :task
    )
  end
end
