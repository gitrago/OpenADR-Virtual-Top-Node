module EpriSheet
  module Primary
    class Network < ::EpriSheet::Base
      # R77:R89 - Static Calculations
      R_BY_X_RATIO = 1 # R68
      SHORT_CIRCUIT_PERFORMANCE = 100 # R67 (Sh)

      def perform
        cache :network
        calculate :impedance
      end

      protected

      # M4:R53
      def calculate_impedance
        imp = sanitized.map do |k, nw|
          data = ref['wire_cable'][nw[:material]][nw[:type]]
          data = Hash[data.map{ |k,v| [k, v*nw[:length]/1000.0]}]
          data[:users] = nw[:length] < 30 ? 0 : ((nw[:length]/30.0 - 1)*3).round(0).to_i
          data[:alloc] = nw[:length] == 0 ? 0 : (data[:users] == 0 ? nw[:customers].to_f/nw[:length] * 30 : nw[:customers].to_f/data[:users])
          [k, data]
        end
        Hash[imp]
      end
    end
  end
end