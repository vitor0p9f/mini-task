defmodule MiniTaskWeb.PageController do
  use MiniTaskWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
