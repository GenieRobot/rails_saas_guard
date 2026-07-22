# frozen_string_literal: true

module RailsSaasGuard
  class Configuration
    DEFAULT_PROBES = %w[/.aws /.env /.git /.hg /.svn /phpmyadmin /pma /server-status /wp-admin /wp-content /wp-login /wordpress /xmlrpc.php].freeze
    WEBDAV_METHODS = %w[PROPFIND PROPPATCH MKCOL COPY MOVE LOCK UNLOCK SEARCH].freeze
    attr_accessor :block_probe_paths, :event_handler, :safelist
    attr_reader :blocked_methods, :probe_prefixes, :throttles
    attr_writer :discriminator_secret
    def initialize
      @block_probe_paths = true
      @blocked_methods = []
      @probe_prefixes = DEFAULT_PROBES.dup
      @throttles = []
      @event_handler = default_event_handler
    end

    def discriminator_secret
      @discriminator_secret || (Rails.application.secret_key_base if defined?(Rails.application) && Rails.application) || ENV["RAILS_SAAS_GUARD_SECRET"]
    end

    def general_requests(limit: 300, period: 300, exclude: %r{\A/(?:assets|packs)/})
      throttle("general/ip", limit:, period:) { |r| r.ip unless r.path.match?(exclude) }
    end

    def devise_defaults!(login_path: "/users/sign_in", password_path: "/users/password", signup_path: "/users")
      throttle("login/ip", limit: 5, period: 60) { |r| r.ip if r.post? && r.path == login_path }
      throttle("login/identity", limit: 5, period: 60, sensitive: true) { |r| r.params.dig("user", "email").to_s.strip.downcase.gsub(/\s+/, "") if r.post? && r.path == login_path }
      throttle("password_reset/ip", limit: 5, period: 3600) { |r| r.ip if r.post? && r.path == password_path }
      throttle("signup/ip", limit: 10, period: 60) { |r| r.ip if r.post? && r.path == signup_path }
    end

    def endpoint(name, path:, limit:, period:, methods: nil, discriminator: :ip)
      allowed = Array(methods).map { |m| m.to_s.upcase }
      throttle(name, limit:, period:, sensitive: discriminator != :ip) do |r|
        next unless path === r.path
        next if allowed.any? && !allowed.include?(r.request_method)
        (discriminator == :ip) ? r.ip : discriminator.call(r)
      end
    end

    def api_prefix(prefix = "/api/", limit: 60, period: 60)
      endpoint("api/token", path: ->(path) { path.start_with?(prefix) }, limit:, period:, discriminator: ->(r) {
        scheme, token = r.get_header("HTTP_AUTHORIZATION").to_s.split(/\s+/, 2)
        token if scheme&.casecmp?("Bearer")
      })
    end

    def block_webdav_methods! = (@blocked_methods = WEBDAV_METHODS.dup)

    def throttle(name, limit:, period:, sensitive: false, &block)
      discriminator = sensitive ? ->(r) {
        value = block.call(r)
        RailsSaasGuard.sensitive_key(value) if value && !value.empty?
      } : block
      @throttles << {name: "rails_saas_guard/#{name}", limit:, period:, discriminator:}
    end

    def validate!
      raise ConfigurationError, "throttle limits and periods must be positive" if throttles.any? { |p| p[:limit] <= 0 || p[:period] <= 0 }
      if throttles.any? { |p| p[:name].match?(/identity|token|portal/) } && discriminator_secret.to_s.empty?
        raise ConfigurationError, "set discriminator_secret or RAILS_SAAS_GUARD_SECRET"
      end
    end

    private

    def default_event_handler
      return unless defined?(Rails.logger)

      ->(event) { Rails.logger.warn({event: "rails_saas_guard", **event}.to_json) }
    end
  end
end
