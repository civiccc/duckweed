require 'socket'

module Duckweed
  module GraphiteMethods
    CONFIG_DEFAULTS = {
      'port' => 2003,
      'interval' => :minutes,
      'pattern' => 'duckweed.%s',
    }

    def self.setup(app)
      config_path =
        File.expand_path('../../graphite.yml', File.dirname(__FILE__))
      return unless File.exist? config_path

      config = CONFIG_DEFAULTS.merge(YAML.load_file(config_path))

      socket = UDPSocket.new
      socket.connect(config['host'], config['port'])

      app.set :graphite_socket   => socket,
              :graphite_interval => config['interval'].to_sym,
              :graphite_pattern  => config['pattern']

    rescue StandardError => ex
      $stderr.puts "Graphite init failed: #{ex}"
    end

    def update_graphite(event, counters)
      return unless settings.respond_to? :graphite_socket

      interval = settings.graphite_interval

      # Build and sanitize path
      path = settings.graphite_pattern % event.gsub('/', '-')

      # Get counter value
      value = counters[interval]

      # Normalize time to middle of bucket
      bucket_size = Duckweed::App::INTERVAL[interval][:bucket_size]
      time = timestamp - (timestamp % bucket_size) + (bucket_size / 2)

      settings.graphite_socket.puts "#{path} #{value} #{time}\n"
    rescue StandardError => ex
      logger.error "graphite_send failed: #{ex}"
    end
  end
end
