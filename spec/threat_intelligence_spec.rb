# frozen_string_literal: true

require "open3"

RSpec.describe "threat intelligence report" do
  it "emits only relevant recent CVE identifiers and links" do
    root = File.expand_path("..", __dir__)
    stdout, stderr, status = Open3.capture3(
      File.join(root, "script/threat_intelligence"),
      "--since", "2026-07-15",
      "--rails-file", File.join(__dir__, "fixtures/rails_security.json"),
      "--cisa-file", File.join(__dir__, "fixtures/cisa_kev.json")
    )

    expect(status).to be_success, stderr
    expect(stdout).to include("CVE-2026-12345", "CVE-2026-54321")
    expect(stdout).not_to include("CVE-2025-99999", "CVE-2026-77777", "Rails test advisory")
  end
end
