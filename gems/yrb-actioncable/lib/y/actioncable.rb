# frozen_string_literal: true

require "y/actioncable/adapter/redis"
require "y/actioncable/adapter/test"
require "y/actioncable/configuration"
require "y/actioncable/engine"
require "y/actioncable/reliable"
require "y/actioncable/sync"
require "y/actioncable/tracker"
require "y/actioncable/version"

module Y
  module Actioncable
    # Your code goes here...
    module_function def config # rubocop:disable Style/AccessModifierDeclarations
      @config ||= Y::Actioncable::Configuration.new
    end
  end
end
