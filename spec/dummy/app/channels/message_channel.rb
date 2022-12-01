# frozen_string_literal: true

class MessageChannel < ApplicationCable::Channel
  include Y::Actioncable::ReliableChannel

  reliable_broadcast :message
end
