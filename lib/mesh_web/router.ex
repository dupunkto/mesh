defmodule MeshWeb.Router do
  @moduledoc false
  use MeshWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MeshWeb do
    pipe_through :api

    get "/ping", APIController, :ping
    get "/state", APIController, :state
  end
end
