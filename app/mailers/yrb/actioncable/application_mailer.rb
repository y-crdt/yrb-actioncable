# frozen_string_literal: true

module Yrb
  module Actioncable
    class ApplicationMailer < ActionMailer::Base
      default from: "from@example.com"
      layout "mailer"
    end
  end
end
