require 'bundler/setup'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w(-fs --color)
  t.pattern = "spec/**/*_spec.rb"
end

task :lib do
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "lib"))
  require 'duckweed'
end

task :authorize, :auth_token, :needs => :lib do |t, args|
  Duckweed::Token.authorize(args[:auth_token])
end

task :deauthorize, :auth_token, :needs => :lib do |t, args|
  Duckweed::Token.authorize(args[:auth_token])
end

task :default => :spec
