$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(__FILE__)))
require 'duckweed/app'
run Duckweed::App
