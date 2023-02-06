# frozen_string_literal: true

module Y
  module Actioncable
    class Configuration
      attr_accessor :sync

      def initialize
        @sync = {}
      end

      def sync_adapter # rubocop:disable Metrics/MethodLength
        adapter = sync.fetch("adapter", "redis")

        path_to_adapter = "y/actioncable/adapter/#{adapter}"
        begin
          require path_to_adapter
        rescue LoadError => e
          # We couldn't require the adapter itself. Raise an exception that
          # points out config typos and missing gems.
          if e.path == path_to_adapter
            # We can assume that a non-builtin adapter was specified, so it's
            # either misspelled or missing from Gemfile.
            raise e.class,
                  "Could not load the '#{adapter}' Y::Actioncable sync adapter. Ensure that the adapter is spelled correctly in config/sync.yml and that you've added the necessary adapter gem to your Gemfile.", e.backtrace

            # Bubbled up from the adapter require. Prefix the exception message
            # with some guidance about how to address it and reraise.
          else
            raise e.class,
                  "Error loading the '#{adapter}' Y::Actioncable sync adapter. Missing a gem it depends on? #{e.message}", e.backtrace
          end
        end

        adapter = adapter.camelize
        "Y::Actioncable::Adapter::#{adapter}".constantize
      end
    end
  end
end
