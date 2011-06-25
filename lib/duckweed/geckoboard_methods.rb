module Duckweed
  module GeckoboardMethods
    def geckoboard_jsonify_for_counts(values)
      items = [values].flatten.map do |value|
        {:text => "", :value => value}
      end
      {:item => items}.to_json
    end

    def geckoboard_jsonify_for_chart(values, times)
      min, max    = values.min, values.max
      mid         = (max + min).to_f / 2
      {
        :item     => values,
        :settings => {
          :axisx  => times,
          :axisy  => [min, mid, max],
          :colour => 'ff9900'
        }
      }.to_json
    end
  end # module GeckoboardMethods
end # module Duckweed
