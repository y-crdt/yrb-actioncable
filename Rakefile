# frozen_string_literal: true

require "bundler/setup"

APP_RAKEFILE = File.expand_path("spec/dummy/Rakefile", __dir__)

load "rails/tasks/engine.rake"
load "rails/tasks/statistics.rake"

require "bundler/gem_tasks"

begin
  require "rspec/core"
  require "rspec/core/rake_task"

  desc "Run all specs in spec directory (excluding plugin specs)"
  RSpec::Core::RakeTask.new(spec: "app:db:test:prepare")

  task test: :spec
  task default: %i[test]
rescue LoadError
  # Ok
end

begin
  require "rubocop/rake_task"

  RuboCop::RakeTask.new
rescue LoadError
  # Ok
end

begin
  require "yard"

  YARD::Rake::YardocTask.new

  task docs: :environment do
    `yard server --reload`
  end
rescue LoadError
  # Ok
end
