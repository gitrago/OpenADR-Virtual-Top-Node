module EpriSheet
  module Secondary
    class LoadVoltage < ::EpriSheet::Base
      def perform
        super
        calculate :min_max
        calculate :install
      end

      protected

      def calculate_data
        phv = epri.pvol[@key].data
        imp = epri.impd[:phase].data
        u2f = transformer.impedance[:u2f] 
        ps = ::EpriSheet::Primary::Ders::PHASE_SHIFT[2**@key]

        base_u_abs = nil
        prev_delta_u = 0
        data = (0..1000).step(10).map do |d|
          row = {}

          row[:current] = phv[d][:load_complex]*ps

          if d == 0
            prev_delta_u = row[:delta_u] = imp[d][:z] * row[:current]
            row[:u] = u2f*1000*ps + row[:delta_u]
          else
            prev_delta_u = row[:delta_u] = imp[d][:section] > 0 ? imp[d][:z] * row[:current] + prev_delta_u : 0
            row[:u] = imp[d][:section] > 0 ? u2f*1000*ps + row[:delta_u] : 0
          end

          row[:u_abs] = row[:u].abs
          base_u_abs ||= row[:u_abs]
          row[:pc] = row[:u_abs]/base_u_abs - 1

          [d, row]
        end

        Hash[data]
      end

      def calculate_min_max
        us = @data.map{|k,v| v[:u_abs]}
        [{ u: us.min, pc: us.min/us.first - 1}, { u: us.max, pc: us.max/us.first - 1}]
      end

      def calculate_install
        user = ders.sanitized.detect{|a| a[:user]}
        arr1 = Hash[@data.map{|k,v| [k, v[:pc]]}]
        arr2 = Hash[epri.resv[@key].data.map{|k,v| [k, v[:pc]]}]

        data = {
          stress: max_lookup(user['distance'], arr1),
          increase: max_lookup(user['distance'], arr2)
        }

        netload = ::EpriSheet::Main::NETWORK_LOAD_CONSIDERATION
        netload = user['distance'] > 0 && user['capacity'] > 0 && netload
        data[:diff] = netload ? data[:increase] - data[:stress] : data[:increase]

        data
      end

      private

      def max_lookup(val, arr)
        _, pick = arr.to_a.reverse.detect{|k| k[0] <= val}
        pick
      end
    end
  end
end
