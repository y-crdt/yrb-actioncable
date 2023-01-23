# frozen_string_literal: true

require "y/actioncable/config/abstract_builder"
require "y/actioncable/config/option"
require "y/actioncable/config/validations"

# inspired by https://github.com/doorkeeper-gem/doorkeeper/blob/main/lib/doorkeeper/config.rb
module Y
  module Actioncable
    class MissingConfiguration < StandardError
      def initialize
        super("Configuration for y-rb_actioncable is missing. " \
              "Do you have an initializer?")
      end
    end

    class MissingConfigurationBuilderClass < StandardError; end

    class << self
      def configure(&block)
        @config = Config::Builder.new(&block).build
      end

      def configuration
        @config || (raise MissingConfiguration)
      end

      alias config configuration
    end

    class Config
      class Builder < AbstractBuilder
      end

      # Replace with `default: Builder` when we drop support of Rails < 5.2
      mattr_reader(:builder_class) { Builder }

      extend Option
      include Validations

      option :redis, default: lambda {
        raise "A Redis client must be configured at initialization time"
      }
    end
  end
end
