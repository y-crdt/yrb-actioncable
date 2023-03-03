# frozen_string_literal: true

class SyncChannel < ApplicationCable::Channel
  include Y::ActionCable::Sync

  def subscribed
    sync_for(session)
  end

  def receive(message)
    sync_to(session, message)
  end

  private

  def session
    @session ||= Session.new(params[:path])
  end
end
