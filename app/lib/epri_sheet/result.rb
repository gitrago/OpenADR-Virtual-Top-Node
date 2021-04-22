module EpriSheet
  class Result < Base
    LIMITS = [0.03, 213.9, 248.4, 253]

    def perform
      super
      calculate :voltage_profile
      calculate :voltage_change
    end

    def calculate_voltage_profile
      data = epri.resv.map { |_, i| Hash[i.data.map { |k, v| [k, v[:u_abs]] }] }
      data = { 'L1' => data[0], 'L2' => data[1], 'L3' => data[2] }
      data['Un +10%'] = Hash[data['L1'].map { |k, _| [k, 253] }]
      data['Un +8%'] = Hash[data['L1'].map { |k, _| [k, 248.4] }]
      data['Un -7%'] = Hash[data['L1'].map { |k, _| [k, 213.9] }]

      # for setting upper and lower boundary of graph
      data[:minv] = [%w[L1 L2 L3].map { |i| (data[i].values - [0]).min }.min, 213.9].min
      data[:maxv] = [%w[L1 L2 L3].map { |i| (data[i].values - [0]).max }.max, 253.0].max
      data[:minv] = data[:minv] > 0 ? data[:minv] * 0.95 : data[:minv] * 1.05
      data[:maxv] = data[:maxv] < 0 ? data[:maxv] * 0.95 : data[:maxv] * 1.05

      data
    end

    def calculate_voltage_change
      data = epri.resv.map { |_, i| Hash[i.data.map { |k, v| [k, v[:pc]] }] }
      data = { 'L1' => data[0], 'L2' => data[1], 'L3' => data[2] }
      data['Series 4'] = Hash[data['L1'].map { |k, _| [k, 0.03] }]

      # for setting upper and lower boundary of graph
      data[:minv] = %w[L1 L2 L3].map { |i| (data[i].values - [0]).min }.min
      data[:maxv] = %w[L1 L2 L3].map { |i| (data[i].values - [0]).max }.max
      data[:minv] = data[:minv] > 0 ? data[:minv] * 0.95 : data[:minv] * 1.05
      data[:maxv] = data[:maxv] < 0 ? data[:maxv] * 0.95 : data[:maxv] * 1.05

      data
    end

    def calculate_data
      @mini = epri.resv.map { |_, i| i.min_max[0] }
      @maxi = epri.resv.map { |_, i| i.min_max[1] }

      fields = [:vol_change_1, :vol_change_2, :vol_change_max,
        :starting_voltage, :max_line_voltage, :min_line_voltage]

      @r = {}
      fields.each { |f| @r[f] = send(f) }

      user = ders.sanitized.detect { |a| a[:user] }
      rvc = user['capacity'].zero? ? 0 : epri.load.map { |_, i| i.install[:diff] }.max
      @r[:rapid_vol_change] = { val: rvc, label: rvc.zero? ? '' : 'at the branch of the HMKE to be tested' }

      @r
    end

    protected

    def max_line_voltage
      { val: max_at(:u), label: @r[:vol_change_2][:label] }
    end

    def min_line_voltage
      { val: min_at(:u), label: @r[:vol_change_1][:label] }
    end

    def starting_voltage
      epri.resv.map { |_, i| i.data[0][:u_abs] }.sum / epri.resv.count
    end

    def vol_change_max
      i66 = @r[:vol_change_1][:val]
      i67 = @r[:vol_change_2][:val]
      k66 = @r[:vol_change_1][:label]
      k67 = @r[:vol_change_2][:label]
      val = [i66, i67].max
      label = i67 > i66 ? "voltage increase #{k67}" : "voltage drop #{k66}"
      { val: val, label: label }
    end

    def vol_change_2
      max = max_at(:pc)
      pca = values_at(:pc)[1]

      return { val: max, label: 'L1 Phase' } if max.abs == pca[0].abs
      return { val: max, label: 'L2 Phase' } if max.abs == pca[1].abs
      return { val: max, label: 'L3 Phase' } if max.abs == pca[2].abs

      { val: max, label: 'symmetric in all 3 phases' }
    end

    def vol_change_1
      min = min_at(:pc)
      pca = values_at(:pc)[0]

      return { val: min, label: 'L1 Phase' } if min.abs == pca[0].abs
      return { val: min, label: 'L2 Phase' } if min.abs == pca[1].abs
      return { val: min, label: 'L3 Phase' } if min.abs == pca[2].abs

      { val: min, label: 'symmetric in all 3 phases' }
    end

    private

    def values_at(name)
      [@mini, @maxi].map { |r| r.map { |i| i[name] } }
    end

    def min_at(name)
      values_at(name)[0].min.abs
    end

    def max_at(name)
      values_at(name)[1].max.abs
    end
  end
end
