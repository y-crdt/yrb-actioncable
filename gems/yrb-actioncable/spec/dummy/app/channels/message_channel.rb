# frozen_string_literal: true

class MessageChannel < ApplicationCable::Channel
  include Y::ActionCable::Reliable
  include Y::ActionCable::Sync
end
