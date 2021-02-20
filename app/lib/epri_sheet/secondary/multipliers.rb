module EpriSheet
  module Secondary
    class Multipliers < ::EpriSheet::Base
      NETWORK_LOAD = { "HIGH" => 2.0, "NORMAL" => 1.0, "LOW" => 0.5 }

      protected

      def calculate_data
        netload = ::EpriSheet::Main::NETWORK_LOAD_CONSIDERATION

        res = (0..1000).step(10).map do |d|
          section = epri.impd[:phase].data[d][:section]
          mults = {section: section }
          mults[:consumer] = network.impedance.key?(section) ? network.impedance[section][:alloc] : 0

          mults[:network] = netload ? NETWORK_LOAD[netload] : 0

          phase = Hash[pd[:phase].map{|k,v| [k.gsub(/[^0-9]/, '').to_i, v]}]
          (1..3).each{ |p| mults[p] = phase[p].zero? ? 1.0 : 1.0/(1+phase[p]) }

          [d, mults]
        end

        res = Hash[res]

        prev = 0
        (0..1000).step(10).reverse_each do |d|
          prev = res[d][:load] = res[d][:section] > 0 ? prev - 0.35*res[d][:consumer]*res[d][:network] : 0
        end

        res[0][:load] = res[10][:load]
        res
      end
    end
  end
end