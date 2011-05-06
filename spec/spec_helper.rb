require 'rspec'
require 'rack/test'

$LOAD_PATH.unshift(File.expand_path(File.join(__FILE__, "..", "..", "lib")))
require 'duckweed'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end
