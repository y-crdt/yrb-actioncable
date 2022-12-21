# frozen_string_literal: true

class SyncChannel < ApplicationCable::Channel
  def subscribed
    stream_for session
  end

  def receive(data)
    SyncChannel.broadcast_to(session, data)
  end

  private

  Session = Struct.new(:path) do
    def to_s
      "sessions:#{path}"
    end
  end
  private_constant :Session

  def session
    Session.new(path)
  end

  def path
    params[:path]
  end
end
