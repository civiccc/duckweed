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

      hoptoad_config = YAML.load_file(hoptoad_yml)[ENV["RACK_ENV"]]

      if hoptoad_config && hoptoad_config["api_key"]
        HoptoadNotifier.configure {|c| c.api_key = hoptoad_config["api_key"]}
        use HoptoadNotifier::Rack
        enable :raise_errors
      end
    end

  end
end
