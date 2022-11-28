# frozen_string_literal: true

module Yrb
  module Actioncable
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
