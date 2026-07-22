# frozen_string_literal: true

require "rails/generators"
module RailsSaasGuard
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      def create_initializer = template("initializer.rb", "config/initializers/rails_saas_guard.rb")
    end
  end
end
