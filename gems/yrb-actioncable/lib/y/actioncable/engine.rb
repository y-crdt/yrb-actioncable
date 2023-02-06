# frozen_string_literal: true

module Y
  module Actioncable
    class Engine < ::Rails::Engine
      isolate_namespace Y::Actioncable

      config.generators do |g|
        g.test_framework :rspec
        g.assets false
        g.helper false
      end

      initializer "y_actioncable.set_configs" do |app|
        app.paths.add "config/sync", with: "config/sync.yml"

        if (config_path = Pathname.new(app.config.paths["config/sync"].first)).exist?
          sync = Rails.application.config_for(config_path).to_h.with_indifferent_access
          Y::Actioncable.config.sync = sync
        end
      end
    end
  end
end
