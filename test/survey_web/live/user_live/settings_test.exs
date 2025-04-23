defmodule SurveyWeb.UserLive.SettingsTest do
  use SurveyWeb.ConnCase, async: true

  alias Survey.Accounts
  import Phoenix.LiveViewTest
  import Survey.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings")

      # Updated assertions: Only check for email-related elements
      assert html =~ "Account Settings"
      assert html =~ "Manage your account email address"
      assert html =~ "Change Email"
      refute html =~ "Save Password" # Ensure password elements are gone
      refute html =~ "New password"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_user(user_fixture(),
          # Simulate token being slightly older than sudo mode timeout
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/users/settings")
        |> follow_redirect(conn, ~p"/users/log-in") # Should redirect to login for re-auth

      # Check the flash message indicating re-authentication is needed
      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user email", %{conn: conn, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      # Check for the confirmation message
      assert result =~ "A link to confirm your email change has been sent to the new address."
      # Ensure the original user email still exists until confirmed
      assert Accounts.get_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          # Simulate invalid change event data
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email" # Button should still be visible
      assert result =~ "must have the @ sign and no spaces" # Validation message
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          # Simulate submitting the same email
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change Email" # Button should still be visible
      assert result =~ "did not change" # Validation message
    end
  end

  # describe "update password form" do ... end block removed entirely

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          # Simulate the action that sends the email update link
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      # Visit the confirmation link
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings" # Redirect back to settings
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      # Verify email change in DB
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      # Try using the same confirmation token again
      {:error, redirect_again} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path_again, flash: flash_again}} = redirect_again
      assert path_again == ~p"/users/settings"
      assert %{"error" => message_again} = flash_again
      assert message_again == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      # Ensure original email is still there
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn() # Unauthenticated connection
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
