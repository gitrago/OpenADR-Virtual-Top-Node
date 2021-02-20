module EpriSheet
  module Primary
    class Transformer < ::EpriSheet::Base
      def perform
        cache :transformer
        calculate :impedance
      end

      protected

      # - Underlying mains and transformer impedance calculation
      # - transformer power and epsilon calculations
      # - some static values moved to constants above
      # - R77:R89 and W23:Y23
      def calculate_impedance
        data = {sn: pd[:transformer][:power], type: pd[:transformer][:type] }
        data[:ptn], data[:e] = ref['transformer'][data[:type]][data[:sn]].values_at('power', 'epsilon') # W23, X23
        data[:er] = data[:ptn] / data[:sn] * 100 # R77
        data[:ex] = (data[:e]**2 - data[:er]**2)**0.5 # R78
        data[:u2] = 0.42*(1 + pd[:transformer][:position]) # R72
        data[:zz] = data[:e]/100.0 * (data[:u2]**2) / data[:sn] * 1000 # R79
        data[:cosphiz] = data[:er]/data[:e] # R80
        data[:rtr] = data[:zz] * data[:cosphiz] # R81
        data[:xtr] = data[:zz]*(1 - data[:cosphiz]**2)**0.5 # R82
        data[:r_x] = data[:rtr]/data[:xtr] # R83
        data[:zh] = data[:u2]**2/Network::SHORT_CIRCUIT_PERFORMANCE # R84
        data[:xh] = (1.0/(1+Network::R_BY_X_RATIO**2))**0.5*data[:zh] # R86
        data[:rh] = data[:xh] * Network::R_BY_X_RATIO # R85
        data[:rtrh] = data[:rtr] + data[:rh] # R87
        data[:xtrh] = data[:xtr] + data[:xh] #R88
        data[:r_x_th] = data[:rtrh]/data[:xtrh] # R89
        data[:u2f] = pd[:transformer][:voltage] > 0 ? pd[:transformer][:voltage]/1000 : data[:u2]/3**0.5 # R73

        data
      end
    end
  end
end