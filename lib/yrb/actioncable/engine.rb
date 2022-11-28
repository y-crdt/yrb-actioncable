# frozen_string_literal: true

module Yrb
  module Actioncable
    class Engine < ::Rails::Engine
      isolate_namespace Yrb::Actioncable

      config.generators do |g|
        g.test_framework :rspec
        g.assets false
        g.helper false
      end
    end
  end
end
