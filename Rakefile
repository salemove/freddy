require "bundler/gem_tasks"

require "rspec/core/rake_task"
require 'bundler/audit/task'
RSpec::Core::RakeTask.new(:spec)
Bundler::Audit::Task.new

task audit: 'bundle:audit'

task ci: :spec
task default: :spec
task :spec => :audit
