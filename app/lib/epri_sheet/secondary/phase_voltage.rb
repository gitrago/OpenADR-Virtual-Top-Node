module EpriSheet
  module Secondary
    class PhaseVoltage < ::EpriSheet::Base
      CONSUMER_COSJ = 0.9
      CONSUMER_COMPLEX = Complex(CONSUMER_COSJ, -(1-CONSUMER_COSJ**2)**0.5)

      protected

      def calculate_data
        netload = ::EpriSheet::Main::NETWORK_LOAD_CONSIDERATION
        ps = ::EpriSheet::Primary::Ders::PHASE_SHIFT[2**@key]
        u2f = transformer.impedance[:u2f] 

        pcur = epri.pcur.data[@key]
        mult = epri.mult.data
        impl = epri.impd[:phase].data

        prev_delta_u = 0
        data = (0..1000).step(10).map do |d|
          row = {}
          row[:prod] = pcur[d].sum
          row[:load] = mult[d][@key] * mult[d][:load]
          row[:load_complex] = CONSUMER_COMPLEX * row[:load]
          row[:load_prod_complex] = row[:prod] + row[:load_complex]
          row[:current] = netload ? row[:load_prod_complex] * ps : row[:prod] * ps

          if d == 0
            prev_delta_u = row[:delta_u] = impl[d][:z] * row[:current]
            row[:u] = u2f*1000*ps + row[:delta_u]
          else
            prev_delta_u = row[:delta_u] = impl[d][:section] > 0 ? impl[d][:z] * row[:current] + prev_delta_u : 0
            row[:u] = impl[d][:section] > 0 ? u2f*1000*ps + row[:delta_u] : 0
          end

          row[:u_abs] = row[:u].abs

          [d, row]
        end

        Hash[data]
      end
    end
  end
end