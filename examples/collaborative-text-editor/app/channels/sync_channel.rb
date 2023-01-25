# frozen_string_literal: true

class SyncChannel < ApplicationCable::Channel
  include Y::Actioncable::Sync

  def initialize(connection, identifier, params = nil)
    super

    load { |id| load_doc(id) }
  end

  def subscribed
    stream_for(session, coder: ActiveSupport::JSON) do |message|
      # integrate updates in the y-rb document
      integrate(message)

      # persist document
      persist { |id, update| save_doc(id, update) }
    end

    # negotiate initial state with client
    initiate
  end

  def receive(message)
    # broadcast update to all connected clients on all servers
    sync_to(session, message)
  end

  private

  def session
    @session ||= Session.new(params[:path])
  end

  def load_doc(id)
    data = REDIS.get(id)
    data = data.unpack("C*") unless data.nil?
    data
  end

  def save_doc(id, state)
    REDIS.set(id, state.pack("C*"))
  end
end
