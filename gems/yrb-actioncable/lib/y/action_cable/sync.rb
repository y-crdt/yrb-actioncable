# frozen_string_literal: true

module Y
  module ActionCable
    # A Sync module for Rails ActionCable channels.
    #
    # This module contains a set of utility methods that allows a relatively
    # convenient implementation of a real-time sync channel. The module
    # implements the synchronization steps described in
    # [`y-protocols/sync`](https://github.com/yjs/y-protocols/blob/master/sync.js).
    #
    # @example Create a SyncChannel including this module
    #   class SyncChannel
    #     def subscribed
    #       # initiate sync & subscribe to updates, with optional persistence
    #       # mechanism
    #       sync_for(session) { |id, update| save_doc(id, update) }
    #     end
    #
    #     def update(message)
    #       # broadcast update to all connected clients on all servers
    #       sync_to(session, message)
    #     end
    #   end
    module Sync
      extend ActiveSupport::Autoload
      extend ActiveSupport::Concern

      autoload :Base
      autoload :Field
      autoload :Op
      autoload :Protocol
      autoload :Reliable

      include Base
      include Protocol
    end
  end
end
