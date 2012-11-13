require 'CGI'
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
    params[:until] ||= '-1minute'
    url_params = params.merge('format' => 'json').map { |k, v| "#{k}=#{CGI::escape v}" }.join('&')
    get = Net::HTTP::Get.new("/render?#{url_params}")
    response = JSON.load(GraphiteHTTPMethods.http.request(get).body)
    if response.is_a?(Array) && response[0] && response[0]['datapoints']
      response[0]['datapoints'].map(&:first).compact
    else
      [0]
    end
  end

  def graphite_summarize(metric, period, params)
    graphite_get params.merge('target' =>
                              "summarize(transformNull(duckweed.#{metric}, 0), \"1#{period}\", \"sum\", true)")
  end

  def graphite_summarize_diff(metric, metric2, period, params)
    graphite_get params.merge('target' =>
                              "summarize(diffSeries(transformNull(duckweed.#{metric}, 0), transformNull(duckweed.#{metric2}, 0)), \"1#{period}\", \"sum\", true)")
  end

  def graphite_integral(metric, params)
    graphite_get(params.merge('target' =>
                              "integral(duckweed.#{metric})")).last.to_s
  end
end
