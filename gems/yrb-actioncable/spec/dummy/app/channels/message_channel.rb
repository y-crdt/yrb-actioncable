# frozen_string_literal: true

class MessageChannel < ApplicationCable::Channel
  include Y::Actioncable::Reliable
  include Y::Actioncable::Sync
end
