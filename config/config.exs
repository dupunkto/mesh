import Config

config :mesh, MeshWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MeshWeb.ErrorHTML, json: MeshWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Mesh.PubSub,
  live_view: [signing_salt: "WfNSTWTN"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
