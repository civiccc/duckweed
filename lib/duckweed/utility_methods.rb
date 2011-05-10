module Duckweed

  # These methods extracted here for easier testing.
  module UtilityMethods

    # Geckoboard renders an empty chart if any value is nil/null,
    # so we have to interpolate intermediate values.
    def interpolate *values
      interpolated    = []
      missing         = 0
      last_seen       = nil
      values.each do |val|
        if val.nil?
          missing += 1
        else
          if missing > 0
            left  = (last_seen || val)
            right = val
            step  = (right - left).to_f / (missing + 1)
            (1..missing).each { |i| interpolated << (left + step * i) }
          end
          interpolated << (last_seen = val)
          missing = 0
        end
      end
      (1..missing).each { |i| interpolated << (last_seen || 0) } if missing > 0
      interpolated
    end
  end # module UtilityMethods
end # module Duckweed
