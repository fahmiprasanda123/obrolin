# The Vue app is served from a different origin in development
# (localhost:5173). Behind the Kubernetes ingress everything shares
# obrolin.local, but listing it here keeps direct calls working too.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("ALLOWED_ORIGINS", "http://localhost:5173").split(",").map(&:strip))

    resource "*",
      headers: :any,
      expose: %w[Authorization],
      methods: %i[get post put patch delete options head]
  end
end
