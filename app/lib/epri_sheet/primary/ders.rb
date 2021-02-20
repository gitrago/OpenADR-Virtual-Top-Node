module EpriSheet
  module Primary
    class Ders < ::EpriSheet::Base
      # AJ11:AL17
      PHASE_SHIFT = {
        2 =>  Complex( 1), # L1
        4 =>  Complex(-0.5, -0.866), # L2
        8 =>  Complex(-0.5,  0.866), # L3
        11 => Complex( 0.5, -0.866),  # L12
        17 => Complex( 0.5,  0.866), # L31
        13 => Complex(-1), # L23
        100 => 0, 101 => 0, 103 => 0, 107 => 0
      }

      def perform
        cache :ders
        calculate :current
      end

      protected

      def calculate_current
        pd[:ders].map.with_index do |d, i|
          x = {}
          x[:ia] = case d['connection'].to_i
          when 3 then d['capacity'].to_f/(3**0.5*transformer.impedance[:u2])
          when 1 then d['capacity'].to_f/(transformer.impedance[:u2]/3**0.5)
          else d['capacity'].to_f/(2*transformer.impedance[:u2]/3**0.5)
          end

          f34 = d['connection'].to_i
          f35 = d['connect2phase'].to_i
          x[1] = current_for_phase(f34, f35, 1, x[:ia])
          x[2] = current_for_phase(f34, f35, 2, x[:ia])
          x[3] = current_for_phase(f34, f35, 3, x[:ia])
          x[:ipen] = x[:ia] * PHASE_SHIFT[2**f35 + 10**(f34-1) - 1]
          x[:label] = (65+i).chr

          x
        end
      end

      private

      def current_for_phase(conn, phase, num, curr)
        return curr if conn == 1 && phase == num
        return curr if conn == 2 && phase != num % 3 + 1

        conn == 3 ? curr : 0
      end
    end
  end
end