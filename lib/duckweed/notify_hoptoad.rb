module Duckweed
  module NotifyHoptoad
    def self.extended(klass)
      klass.setup_hoptoad
    end

    def setup_hoptoad
      hoptoad_yml = File.join(
        File.dirname(__FILE__),
        "..",
        "..",
        "config",
        "hoptoad.yml")

      hoptoad_config = YAML.load_file(hoptoad_yml)

      if hoptoad_config && hoptoad_config["api_key"]
        HoptoadNotifier.configure do |c|
          c.api_key = hoptoad_config["api_key"]
          c.environment_name = ENV['RACK_ENV'] if ENV['RACK_ENV']
        end
        use HoptoadNotifier::Rack
        enable :raise_errors
      end
    end

  end
end
