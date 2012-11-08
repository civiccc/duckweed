require 'net/http'
require 'uri'
require 'json'

# A set of methods for talking to the Graphite HTTP interface
module GraphiteHTTPMethods
  class << self
    attr_accessor :http

    def setup(app)
      config_path =
        File.expand_path('../../graphite.yml', File.dirname(__FILE__))
      return unless File.exist? config_path

      config = YAML.load_file(config_path)
      self.http = Net::HTTP.new(config['host'], config['port'] || 80)
    end
  end

  def graphite_get(params)
    url_params = params.merge('format' => 'json').map { |k, v| "#{k}=#{v}" }.join('&')
    get = Net::HTTP::Get.new("/render?#{url_params}")
    response = JSON.load(GraphiteHTTPMethods.http.request(get).body)
    if response.is_a?(Array) && response[0] && response[0]['datapoints']
      response[0]['datapoints'].map(&:first).compact
    else
      []
    end
  end

  def graphite_summarize(metric, period, params)
    graphite_get params.merge('target' =>
                              "summarize(duckweed.#{metric}, \"1#{period}\")")
  end
end
