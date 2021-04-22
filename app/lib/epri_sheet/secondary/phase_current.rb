module EpriSheet
  module Secondary
    class PhaseCurrent < ::EpriSheet::Base
      protected

      def calculate_data
        dist = ders.sanitized.map{|i| i['distance']}

        res = (1..3).map do |phase|
          curr = ders.current.map{|i| i[phase]}
          n = (0..1000).step(10).map do |d|
            ds = curr.length.times.map do |i|
              d <= dist[i] ? curr[i] : 0
            end
            [d, ds]
          end
          [phase, Hash[n]]
        end

        Hash[res]
      end
    end
  end
end