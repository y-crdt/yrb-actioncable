# frozen_string_literal: true

require "y/action_cable/configuration"
require "y/action_cable/engine"
require "y/action_cable/sync"
require "y/action_cable/sync_adapter"
require "y/action_cable/tracker"
require "y/action_cable/version"

module Y
  module ActionCable
    module_function def config # rubocop:disable Style/AccessModifierDeclarations
      @config ||= Y::ActionCable::Configuration.new
    end
  end
end
