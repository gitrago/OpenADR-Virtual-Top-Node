# encoding: UTF-8

module EpriSheet
  module Secondary
    # Impedence Map Phase/PEN driver
    class Impedance < ::EpriSheet::Base
      protected

      def calculate_data
        cumlen = [0]
        network.sanitized.each{|k,v| cumlen << cumlen[-1] + v[:length]}

        data = (0..1000).step(10).map do |dist|
          section = cumlen.index{|i| dist <= i}
          r, x = imp_r(section), imp_x(section)
          z = Complex(r, x)
          [dist, {section: section, imp_r: r, imp_x: x, z: z }]
        end

        Hash[data]
      end

      private

      def imp_r(section)
        return transformer.impedance[:rh] + transformer.impedance[:rtr] if @key != :pen && section.zero?
        return 0 unless network.sanitized.key?(section)
        return 0 if network.sanitized[section][:length] <= 0

        network.impedance[section][@key == :pen ? 'RPEN' : 'Rfázis']/network.sanitized[section][:length]*10
      end

      def imp_x(section)
        return transformer.impedance[:xh] + transformer.impedance[:xtr] if @key != :pen && section.zero?
        return 0 unless network.sanitized.key?(section)
        return 0 if network.sanitized[section][:length] <= 0

        network.impedance[section][@key == :pen ? 'XPEN': 'Xfázis']/network.sanitized[section][:length]*10
      end
    end
  end
end