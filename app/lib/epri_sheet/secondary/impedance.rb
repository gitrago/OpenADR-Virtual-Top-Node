module EpriSheet
  module Secondary
    # Impedence Map Phase/PEN driver
    class Impedance < ::EpriSheet::Base
      protected

      def calculate_data
        data = (0..1000).step(10).map do |dist|
          section = section_for_distance(dist)
          r = imp_r(section)
          x = imp_x(section)
          z = Complex(r, x)
          [dist, { section: section, imp_r: r, imp_x: x, z: z }]
        end

        Hash[data]
      end

      def section_for_distance(dist)
        return 0 if dist.zero?

        (1..5).each { |i| return i if dist <= distance_to_network(i) }

        0
      end

      def imp_r(section)
        return transformer.impedance[:rh] + transformer.impedance[:rtr] if @key != :pen && section.zero?
        return 0 unless network.sanitized.key?(section)
        return 0 if network.sanitized[section][:length] <= 0

        network.impedance[section][@key == :pen ? 'RPEN' : 'Rfázis'] / network.sanitized[section][:length] * 10
      end

      def imp_x(section)
        return transformer.impedance[:xh] + transformer.impedance[:xtr] if @key != :pen && section.zero?
        return 0 unless network.sanitized.key?(section)
        return 0 if network.sanitized[section][:length] <= 0

        network.impedance[section][@key == :pen ? 'XPEN' : 'Xfázis'] / network.sanitized[section][:length] * 10
      end

      private

      def distance_to_network(n)
        n.times.map do |i|
          x = network.sanitized[i + 1]
          x ? x[:length] : 0
        end.sum
      end
    end
  end
end
