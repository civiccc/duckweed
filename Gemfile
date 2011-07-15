source "http://rubygems.org"

# json has C components, so if you update the version, make sure
# there's an rpgem-json package available for it.
gem "json", "1.4.3"

gem "sinatra"
gem "redis"
gem "hoptoad_notifier"

group(:test) do
  gem "rspec",    "~>2.0"
  gem "rack-test"
  gem "rake"
  gem "ZenTest"
  gem "mock_redis"
end

group(:development) do
  gem "ruby-debug"
end
