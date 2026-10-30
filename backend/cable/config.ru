# Standalone ActionCable server: `bundle exec puma -p 3000 cable/config.ru`.
# Runs from the same image as the API, but scales independently, so long-lived
# WebSocket connections never compete with short REST requests for threads.
require_relative "../config/environment"
Rails.application.eager_load!

map "/up" do
  run ->(_env) { [ 200, { "content-type" => "text/plain" }, [ "ok" ] ] }
end

map "/" do
  run ActionCable.server
end
