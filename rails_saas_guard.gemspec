# frozen_string_literal: true

require_relative "lib/rails_saas_guard/version"
Gem::Specification.new do |spec|
  spec.name = "rails_saas_guard"
  spec.version = RailsSaasGuard::VERSION
  spec.authors = ["Daniel Badde"]
  spec.email = ["github@badde.media"]
  spec.summary = "Secure Rack::Attack defaults for production Rails SaaS applications"
  spec.description = "Configurable throttling, conservative probe blocking, safe responses, and explicit Ubuntu operations templates."
  spec.homepage = "https://github.com/GenieRobot/rails_saas_guard"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata = {"allowed_push_host" => "https://rubygems.org", "source_code_uri" => spec.homepage, "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md", "rubygems_mfa_required" => "true"}
  spec.files = Dir.chdir(__dir__) { Dir["CHANGELOG.md", "CONTRIBUTING.md", "LICENSE.txt", "README.md", "SECURITY.md", "docs/**/*", "exe/*", "examples/**/*", "lib/**/*", "ops/**/*", "sig/**/*"].select { |f| File.file?(f) } }
  spec.bindir = "exe"
  spec.executables = ["rails_saas_guard"]
  spec.require_paths = ["lib"]
  spec.add_dependency "rack", ">= 2.2", "< 4"
  spec.add_dependency "rack-attack", ">= 6.7", "< 7"
end
