RailsSaasGuard.configure do |config|
  config.discriminator_secret = ENV.fetch("RAILS_SAAS_GUARD_SECRET")
  config.general_requests limit: 200, period: 1.minute
  config.devise_defaults!
  config.endpoint "expensive/ip", path: "/expensive", methods: :post, limit: 2, period: 1.minute
  config.api_prefix "/api/", limit: 3, period: 1.minute
  config.endpoint "proxy/ip", path: "/proxy-bucket", limit: 2, period: 1.minute
  config.block_webdav_methods!
end
