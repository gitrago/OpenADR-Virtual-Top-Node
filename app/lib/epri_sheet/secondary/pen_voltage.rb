module EpriSheet
  module Secondary
    class PenVoltage < ::EpriSheet::Base
      protected

      def calculate_data
        imp = epri.impd[:pen].data
        pv1 = epri.pvol[1].data
        pv2 = epri.pvol[2].data
        pv3 = epri.pvol[3].data

        prev_delta_u = 0
        data = (0..1000).step(10).map do |d|
          row = {}
          row[:current] = [pv1, pv2, pv3].map{|pv| pv[d][:current]}.sum
          if d == 0
            prev_delta_u = row[:delta_u] = imp[d][:z] * row[:current]
          else
            prev_delta_u = row[:delta_u] = imp[d][:section] > 0 ? imp[d][:z] * row[:current] + prev_delta_u : 0
          end
          [d, row]
        end

        Hash[data]
      end
    end
  end
end