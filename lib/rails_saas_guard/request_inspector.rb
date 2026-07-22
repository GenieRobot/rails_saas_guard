# frozen_string_literal: true

module RailsSaasGuard
  class RequestInspector
    MAX_BYTES = 4096
    PHP_PATH = %r{(?:\A|/)[^/?#]*\.php(?:\z|/)}i
    def initialize(configuration) = (@configuration = configuration)

    def probe?(request)
      raw = request.get_header("PATH_INFO").to_s.byteslice(0, MAX_BYTES)
      paths = [raw]
      2.times do
        decoded = Rack::Utils.unescape_path(paths.last)
        break if decoded == paths.last
        paths << decoded
      end
      paths.map { |p| p.encode("UTF-8", invalid: :replace, undef: :replace).tr("\\", "/").downcase }.any? do |path|
        path.match?(PHP_PATH) || @configuration.probe_prefixes.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
      end
    rescue ArgumentError
      false
    end
  end
end
