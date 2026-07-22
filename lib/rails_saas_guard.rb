# frozen_string_literal: true

require "json"
require "openssl"
require "rack/attack"
require_relative "rails_saas_guard/version"
require_relative "rails_saas_guard/configuration"
require_relative "rails_saas_guard/request_inspector"
require_relative "rails_saas_guard/responder"

module RailsSaasGuard
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class << self
    attr_writer :configuration
    def configuration = (@configuration ||= Configuration.new)
    def configure = yield(configuration)
    def reset! = (self.configuration = Configuration.new)
    def sensitive_key(value) = OpenSSL::HMAC.hexdigest("SHA256", configuration.discriminator_secret.to_s, value.to_s)[0, 32]

    def install!(rack_attack: Rack::Attack)
      configuration.validate!
      rack_attack.safelist("rails_saas_guard/safelist", &configuration.safelist) if configuration.safelist
      configuration.throttles.each do |policy|
        rack_attack.throttle(policy[:name], limit: policy[:limit], period: policy[:period], &policy[:discriminator])
      end
      inspector = RequestInspector.new(configuration)
      rack_attack.blocklist("rails_saas_guard/probes") { |request| inspector.probe?(request) } if configuration.block_probe_paths
      methods = configuration.blocked_methods
      rack_attack.blocklist("rails_saas_guard/methods") { |request| methods.include?(request.request_method.to_s.upcase) } if methods.any?
      rack_attack.throttled_responder = Responder.new(status: 429)
      rack_attack.blocklisted_responder = Responder.new(status: 403)
      install_instrumentation
      self
    end

    private

    def install_instrumentation
      return unless defined?(ActiveSupport::Notifications)
      return if @instrumentation_installed

      ActiveSupport::Notifications.subscribe("rack.attack") do |_name, _start, _finish, _id, payload|
        request = payload[:request]
        next unless request && configuration.event_handler

        configuration.event_handler.call(
          type: request.env["rack.attack.match_type"],
          policy: request.env["rack.attack.matched"],
          client_ip: request.ip,
          method: request.request_method
        )
      end
      @instrumentation_installed = true
    end
  end
end
require_relative "rails_saas_guard/railtie" if defined?(Rails::Railtie)
