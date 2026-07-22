# frozen_string_literal: true

module RailsSaasGuard
  class Responder
    def initialize(status:) = (@status = status)

    def call(request)
      retry_after = request.env.dig("rack.attack.match_data", :period)
      json = request.path.start_with?("/api/") || request.get_header("HTTP_ACCEPT").to_s.include?("json")
      headers = {"Content-Type" => json ? "application/json; charset=utf-8" : "text/html; charset=utf-8", "Cache-Control" => "no-store"}
      headers["Retry-After"] = retry_after.to_i.to_s if @status == 429 && retry_after
      message = (@status == 429) ? "Too many requests" : "Forbidden"
      body = json ? JSON.generate(error: message, retry_after:) : "<!doctype html><html><head><meta charset=\"utf-8\"><title>#{message}</title></head><body><main><h1>#{message}</h1><p>Please try again later.</p></main></body></html>"
      [@status, headers, [body]]
    end
  end
end
