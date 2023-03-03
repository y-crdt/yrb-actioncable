# frozen_string_literal: true

module Y
  module ActionCable
    module SyncAdapter
      extend ActiveSupport::Autoload

      autoload :Base
      autoload :Redis
      autoload :Test
    end
  end
end
