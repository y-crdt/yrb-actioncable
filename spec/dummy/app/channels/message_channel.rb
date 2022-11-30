# frozen_string_literal: true

class MessageChannel < ApplicationCable::Channel
  include Y::Actioncable::ReliableChannel

  reliable_broadcast :message

  def subscribed; end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
