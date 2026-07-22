# frozen_string_literal: true

RailsSaasGuard.configure do |config|
  config.general_requests limit: 300, period: 5.minutes
  config.devise_defaults!
  # Opt in only when the application does not support WebDAV:
  # config.block_webdav_methods!
end
