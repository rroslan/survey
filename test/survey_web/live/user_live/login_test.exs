defmodule SurveyWeb.UserLive.LoginTest do
  use SurveyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Survey.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      # Updated assertions to match the magic-link-only view
      assert html =~ "Log in or Reauthenticate"
      assert html =~ "Sign up" # Link to registration
      assert html =~ "Send Login Link" # Button text
      refute html =~ "password" # Ensure password field is gone
    end
  end

  describe "user login - magic link" do
    test "sends magic link email when user exists", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"

      assert Survey.Repo.get_by!(Survey.Accounts.UserToken, user_id: user.id).context ==
               "login"
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  # describe "user login - password" do ... end block removed entirely

  describe "login navigation" do
    test "redirects to registration page when the Sign up link is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _login_live, registration_html} = # Renamed variable for clarity
        lv
        |> element("main a", "Sign up") # Using the actual link text
        |> render_click()
        |> follow_redirect(conn, ~p"/users/register")

      assert registration_html =~ "Register" # Check content of the target page
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with email filled in", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      # Updated assertions for re-auth context
      assert html =~ "Enter your email to receive a link to reauthenticate" # More specific text
      refute html =~ "Sign up" # Registration link shouldn't be prominent
      assert html =~ "Send Login Link" # Button text

      # Keep assertion for pre-filled email
      assert html =~
               ~s(<input type="email" name="user[email]" id="login_form_magic_email" value="#{user.email}")

      # Ensure password field is not present even in re-auth
      refute html =~ "password"
    end
  end
end
