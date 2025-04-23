defmodule SurveyWeb.PageController do
  use SurveyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
