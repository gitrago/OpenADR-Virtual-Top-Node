module EpriSheet
  module Secondary
    class ResultingVoltage < ::EpriSheet::Base
      def perform
        super
        calculate :min_max
      end

      protected

      def calculate_min_max
        us = @data.map { |_k, v| v[:u_abs] } - [0]
        [{ u: us.min, pc: us.min / us.first - 1 }, { u: us.max, pc: us.max / us.first - 1 }]
      end

      def calculate_data
        pen = epri.penv.data
        phv = epri.pvol[@key].data

        base_u_abs = nil
        data = (0..1000).step(10).map do |d|
          row = {}
          row[:u] = pen[d][:delta_u] + phv[d][:u]
          row[:u_abs] = row[:u].abs
          base_u_abs ||= row[:u_abs]
          row[:pc] = row[:u_abs] > 0 ? row[:u_abs] / base_u_abs - 1 : 0
          [d, row]
        end

        Hash[data]
      end
    end
  end
end
