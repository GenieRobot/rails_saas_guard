# frozen_string_literal: true

module RailsShield
  class Railtie < Rails::Railtie
    initializer("rails_shield.install", after: "rack_attack.configure") { config.after_initialize { RailsShield.install! } }
    generators { require_relative "../generators/rails_shield/install_generator" }
  end
end
