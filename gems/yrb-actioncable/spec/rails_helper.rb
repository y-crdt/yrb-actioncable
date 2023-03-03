# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require File.expand_path("./dummy/config/environment", __dir__)

# Prevent database truncation if the environment is production
if Rails.env.production?
  abort("The Rails environment is running in production mode!")
end

require "rspec/rails"

# autoload support files
Dir[Rails.root / "spec" / "support" / "**" / "*.rb"].sort.each { |f| require f }

require "spec_helper"
