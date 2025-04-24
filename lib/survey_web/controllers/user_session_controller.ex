defmodule SurveyWeb.UserSessionController do
  use SurveyWeb, :controller

  alias Survey.Accounts
  alias SurveyWeb.UserAuth

  # Handles login after email confirmation via magic link
  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  # Handles standard magic link login
  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # Magic link login implementation
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, user, tokens_to_disconnect} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params) # user_params might be empty or just contain token, which is fine

      # Handles invalid/expired token
      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # Removed the create/2 function clause for email + password login

  # Removed the update_password/2 function entirely

  # Logout function remains the same
  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
