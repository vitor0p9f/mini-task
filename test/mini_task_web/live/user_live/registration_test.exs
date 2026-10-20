defmodule MiniTaskWeb.UserLive.RegistrationTest do
  use MiniTaskWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MiniTask.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Register"
      assert html =~ "Log in"
      assert has_element?(lv, "#registration_form #user_password")
      assert has_element?(lv, "#registration_form #user_password_confirmation")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "Register"
      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "register user" do
    test "creates account and redirects to log in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      attrs =
        valid_user_attributes(email: email)
        |> Map.put(:password, valid_user_password())
        |> Map.put(:password_confirmation, valid_user_password())

      form = form(lv, "#registration_form", user: attrs)

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Account created successfully. Please log in."
      assert MiniTask.Accounts.get_user_by_email(email).confirmed_at
      assert MiniTask.Repo.all(MiniTask.Accounts.UserToken) == []
    end

    test "requires a password", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> form("#registration_form", user: valid_user_attributes())
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "renders errors when password confirmation does not match", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> form("#registration_form",
          user: %{
            "email" => unique_user_email(),
            "password" => valid_user_password(),
            "password_confirmation" => "different password"
          }
        )
        |> render_submit()

      assert result =~ "does not match password"
    end

    test "registered user can log in with the chosen password", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      password = valid_user_password()

      attrs =
        valid_user_attributes(email: email)
        |> Map.put(:password, password)
        |> Map.put(:password_confirmation, password)

      {:ok, _lv, _html} =
        lv
        |> form("#registration_form", user: attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => email, "password" => password}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user: %{
            "email" => user.email,
            "password" => valid_user_password(),
            "password_confirmation" => valid_user_password()
          }
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Log in"
    end
  end
end
