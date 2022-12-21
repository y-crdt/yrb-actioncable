# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    private

    def current_user
      User.find(1)
    end
  end
end
