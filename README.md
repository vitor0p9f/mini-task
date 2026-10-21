<div align="center">

# MiniTask

**A small collaborative task manager built with Elixir and Phoenix LiveView.**

[![Elixir](https://img.shields.io/badge/Elixir-1.17%2B-4B275F?style=flat-square&logo=elixir&logoColor=white)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-FF6B00?style=flat-square&logo=phoenixframework&logoColor=white)](https://www.phoenixframework.org/)
[![LiveView](https://img.shields.io/badge/LiveView-1.2-7C3AED?style=flat-square)](https://hexdocs.pm/phoenix_live_view/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=flat-square&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)

[Overview](#overview) · [Features](#features) · [Stack](#tech-stack) · [Getting started](#getting-started) · [Usage](#usage) · [Tests](#tests)

</div>

---

## Overview

MiniTask is a small full-stack task management application. Users can create tasks, set their status, assign other people, and see updates in real time.

Each user only sees tasks they created or were assigned to. Task owners can edit and delete their tasks; assignees can follow progress but cannot change them.

This is a personal learning project focused on applying **Elixir**, **Phoenix**, and the surrounding ecosystem in a real application. It is intentionally small, but it covers authentication, database modeling, authorization, real-time updates, UI, testing, and Docker.

> This is a learning project, not a production-hardened product.

---

## Features

- Email and password registration, login, and logout
- Persistent session or session-only login
- Account settings for email and password
- Task creation, editing, deletion, and status updates
- Four statuses: `Pending`, `In progress`, `Done`, and `Cancelled`
- Multiple assignees per task
- Owner/assignee permissions
- Real-time updates through Phoenix PubSub
- Docker support with automatic migrations

---

## How it works

Tasks are visible to their owner and to every assigned user. Only the owner can edit, delete, or change assignees.

Real-time updates use a global PubSub topic named `"tasks"`. When a task is created, updated, or deleted, the other connected LiveViews refresh their task lists.

```text
Browser (LiveView) ──► TaskLive ──► Tasks context ──► Ecto ──► PostgreSQL
                           │
                           └── PubSub ("tasks") ──► other connected LiveViews
```

The user who performs the change refreshes their own list locally. Other users receive the PubSub event and refresh theirs.

---

## Tech stack

| Layer | Technology |
| --- | --- |
| Language | Elixir 1.17+ |
| Web framework | Phoenix 1.8 |
| UI | Phoenix LiveView 1.2 + HEEx |
| Database | PostgreSQL 16 |
| Persistence | Ecto SQL + Postgrex |
| Authentication | `phx.gen.auth` + Bcrypt |
| Tests | ExUnit, `Phoenix.LiveViewTest`, LazyHTML |
| Infrastructure | Docker multi-stage + Elixir releases |

---

## Getting started

### Requirements

- Elixir 1.17+ and a compatible Erlang/OTP version
- PostgreSQL 16
- Port `4000` for the app and `5432` for PostgreSQL
- Node.js is **not** required; assets are built with esbuild and Tailwind CLI

### Run locally

```bash
mix setup
mix phx.server
```

Or start it with IEx:

```bash
iex -S mix phx.server
```

Open:

```text
http://localhost:4000
```

`mix setup` installs dependencies, creates and migrates the development database, runs the seeds, installs the asset tools, and builds the assets.

By default, development expects PostgreSQL at `localhost:5432` with user `postgres`, password `postgres`, and database `mini_task_dev`. If your setup is different, update `config/dev.exs`.

To use only the PostgreSQL container while running the app locally:

```bash
docker compose up -d db
mix setup
mix phx.server
```

To reset the development database:

```bash
mix ecto.reset
```

### Run with Docker

```bash
cp .env.example .env
```

Generate a secure `SECRET_KEY_BASE` and put it in `.env`:

```bash
mix phx.gen.secret
```

If Elixir is not installed on the host, you can use:

```bash
openssl rand -base64 48
```

Then start the containers:

```bash
docker compose up --build
```

Open:

```text
http://localhost:4000
```

Migrations run automatically on container startup because `RUN_MIGRATIONS=true`.

Useful commands:

```bash
# Follow application logs
docker compose logs -f app

# Stop the containers
docker compose down

# Stop and remove the database volume
docker compose down -v
```

### Environment variables

The full list is documented in `.env.example`. The main ones are:

| Variable | Default | Purpose |
| --- | --- | --- |
| `APP_PORT` | `4000` | Host port for the application |
| `PORT` | `4000` | Port Phoenix listens on inside the container |
| `PHX_HOST` | `localhost` | Host used to generate URLs |
| `SECRET_KEY_BASE` | — | Signs cookies and sessions; generate a new value |
| `POSTGRES_USER` | `postgres` | PostgreSQL user |
| `POSTGRES_PASSWORD` | `postgres` | PostgreSQL password |
| `POSTGRES_DB` | `mini_task_prod` | Database used by the Docker app |
| `DATABASE_URL` | — | Optional external database URL |
| `RUN_MIGRATIONS` | `true` | Run migrations when the container starts |

---

## Usage

### 1. Create an account

Open:

```text
http://localhost:4000/users/register
```

Enter an email, a password, and the password confirmation. Passwords must be at least **12 characters** long.

Password registrations are confirmed immediately, so you can log in without configuring an email provider.

### 2. Log in

Open:

```text
http://localhost:4000/users/log-in
```

Choose one of the options:

- **Log in and stay logged in** — keeps the session with a persistent cookie
- **Log in only this time** — keeps the session only for the current browser session

### 3. Create a task

After logging in, you are redirected to:

```text
http://localhost:4000/tasks
```

Click **New task**, fill in the title, optional description, initial status, and assignees, then click **Create task**.

### 4. Assign people

In the **Assignees** section, select the users responsible for the task.

- All registered users are listed except the current user.
- Multiple assignees are allowed.
- Assignees are displayed as colored initial avatars.
- If there are more than four assignees, the UI shows a `+N` indicator.

### 5. Permissions

| Action | Owner | Assignee | Other user |
| --- | :---: | :---: | :---: |
| Create a task | ✅ | ✅ | ✅ |
| View a task | ✅ | ✅ | ❌ |
| Edit a task | ✅ | ❌ | ❌ |
| Delete a task | ✅ | ❌ | ❌ |
| Change assignees | ✅ | ❌ | ❌ |

Assignees see the task with **View only** instead of the edit and delete actions.

### 6. See real-time updates

Open the app in two different browsers or profiles, logged in as different users.

Create, update, or delete a task in one session and watch the list update in the other without a page reload.

### 7. Manage your account

Open:

```text
http://localhost:4000/users/settings
```

You can change your email or password. These actions require **sudo mode**: if the last authentication was more than 20 minutes ago, you need to log in again.

Changing the email requires confirmation through a link sent to the new address.

---

## Project structure

```text
lib/
├── mini_task/
│   ├── accounts.ex              # Authentication and user context
│   ├── accounts/
│   │   ├── scope.ex
│   │   ├── user.ex
│   │   ├── user_notifier.ex
│   │   └── user_token.ex
│   ├── tasks.ex                 # Task context and permissions
│   └── tasks/
│       ├── task.ex
│       └── task_assignment.ex
│
├── mini_task_web/
│   ├── live/
│   │   ├── task_live/           # Task list, form, and real-time updates
│   │   └── user_live/           # Login, registration, and settings
│   ├── controllers/
│   ├── components/
│   ├── router.ex
│   └── user_auth.ex
│
priv/repo/migrations/            # Database migrations
assets/                          # CSS and JavaScript
```

---

## Tests

```bash
mix test
```

Run the project checks:

```bash
mix precommit
```

`mix precommit` runs:

1. `compile --warnings-as-errors`
2. `deps.unlock --unused`
3. `format`
4. `test`

---

## What this project practices

- Elixir pattern matching, guards, pipes, and `with`
- Phoenix contexts and scoped data access
- Ecto schemas, changesets, enums, constraints, and transactions
- Many-to-many relationships through `task_assignments`
- LiveView streams, forms, modals, and real-time updates
- Phoenix PubSub
- Authentication with `phx.gen.auth`, Bcrypt, and sudo mode
- Owner-based authorization in the context layer
- Tailwind CSS, daisyUI, Heroicons, and theme switching
- Docker multi-stage builds and Elixir releases
- ExUnit, `ConnCase`, and `Phoenix.LiveViewTest`

---

## License

This project is licensed under the MIT License. See [LICENSE.txt](LICENSE.txt) for details.

</div>
