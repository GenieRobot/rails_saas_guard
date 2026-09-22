# frozen_string_literal: true

require "rails/generators"
module RailsShield
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      def create_initializer = template("initializer.rb", "config/initializers/rails_shield.rb")
    end
  end
end
