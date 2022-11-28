# frozen_string_literal: true

require "rspec/autorun"

Rails.backtrace_cleaner.remove_silencers!
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec
  config.order = "random"
end
