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
    end
  end
end
