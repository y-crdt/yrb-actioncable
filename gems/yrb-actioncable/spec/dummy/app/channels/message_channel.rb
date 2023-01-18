# frozen_string_literal: true

class MessageChannel < ApplicationCable::Channel
  include Y::Actioncable::Reliable

  reliable_broadcast :message
end
