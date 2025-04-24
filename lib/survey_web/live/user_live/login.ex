defmodule SurveyWeb.UserLive.Login do
  use SurveyWeb, :live_view

  alias Survey.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <.header class="text-center">
          <p>Log in or Reauthenticate</p>
          <:subtitle>
            <%= if @current_scope do %>
              Enter your email to receive a link to reauthenticate.
            <% else %>
              Enter your email to receive a login link.
              <%!--
                Don't have an account? <.link
                  navigate={~p"/users/register"}
                  class="font-semibold text-brand hover:underline"
                  phx-no-format
                >Sign up</.link> for an account now.
              --%>
            <% end %>
          </:subtitle>
        </.header>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="w-6 h-6 shrink-0" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="w-full" variant="primary">
            Send Login Link <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <%!-- Password form and divider removed --%>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    # Only need the email field for the magic link form
    form = to_form(%{"email" => email}, as: "user")

    # No need for trigger_submit anymore
    {:ok, assign(socket, form: form)}
  end

  # handle_event("submit_password", ...) removed

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     # Optional: You might not need to navigate away immediately after requesting the link.
     # Consider removing the push_navigate if you want the user to stay on the page.
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:survey, Survey.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
