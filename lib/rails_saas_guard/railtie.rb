# frozen_string_literal: true

module RailsSaasGuard
  class Railtie < Rails::Railtie
    initializer("rails_saas_guard.install", after: "rack_attack.configure") { config.after_initialize { RailsSaasGuard.install! } }
    generators { require_relative "../generators/rails_saas_guard/install_generator" }
  end
end
