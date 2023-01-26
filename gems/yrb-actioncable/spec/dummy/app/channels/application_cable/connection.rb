# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    private

    def current_user
      self.id = SecureRandom.uuid
    end
  end
end
