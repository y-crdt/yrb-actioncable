# frozen_string_literal: true

module Y
  module ActionCable
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
