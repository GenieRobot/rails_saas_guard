# frozen_string_literal: true

require "rack/mock"

RSpec.describe RailsSaasGuard do
  before { described_class.reset! }

  it "has a version" do
    expect(RailsSaasGuard::VERSION).not_to be_nil
  end

  it "hashes sensitive discriminators without exposing their value" do
    described_class.configuration.discriminator_secret = "test-secret"
    value = described_class.sensitive_key("person@example.com")
    expect(value).to match(/\A[0-9a-f]{32}\z/)
    expect(value).not_to include("person")
  end

  it "blocks PHP script paths case-insensitively and through bounded encoding" do
    inspector = RailsSaasGuard::RequestInspector.new(described_class.configuration)
    %w[/index.php /INDEX.PHP /foo.php/bar /%69ndex%252ephp].each do |path|
      expect(inspector.probe?(Rack::Request.new(Rack::MockRequest.env_for(path)))).to be(true), path
    end
  end

  it "does not block php text in query strings or non-script suffixes" do
    inspector = RailsSaasGuard::RequestInspector.new(described_class.configuration)
    %w[/search?q=index.php /image.php.jpg /legitimate/administrator].each do |path|
      expect(inspector.probe?(Rack::Request.new(Rack::MockRequest.env_for(path)))).to be(false), path
    end
  end

  it "keeps well-known and admin routes available" do
    inspector = RailsSaasGuard::RequestInspector.new(described_class.configuration)
    %w[/.well-known/acme-challenge/token /admin].each do |path|
      expect(inspector.probe?(Rack::Request.new(Rack::MockRequest.env_for(path)))).to be(false)
    end
  end

  it "fails safely on malformed path encoding" do
    inspector = RailsSaasGuard::RequestInspector.new(described_class.configuration)
    environment = Rack::MockRequest.env_for("/")
    environment["PATH_INFO"] = "/%ZZ.php"
    request = Rack::Request.new(environment)
    expect { inspector.probe?(request) }.not_to raise_error
  end

  it "negotiates JSON throttling responses with Retry-After" do
    request = Rack::Request.new(Rack::MockRequest.env_for("/api/widgets", "HTTP_ACCEPT" => "application/json"))
    request.env["rack.attack.match_data"] = {period: 60}
    status, headers, body = RailsSaasGuard::Responder.new(status: 429).call(request)
    expect([status, headers["Retry-After"], JSON.parse(body.join)["error"]]).to eq([429, "60", "Too many requests"])
  end
end
