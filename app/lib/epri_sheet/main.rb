# encoding: UTF-8

module EpriSheet
  class Main

    # F64
    # can be HIGH, NORMAL, LOW or nil (turnoff/disable)
    NETWORK_LOAD_CONSIDERATION = ENV.fetch('EPRI_NETWORK_LOAD_CONSIDERATION', 'NORMAL')

    def self.run(*args)
      new(*args).calc!
    end

    attr_reader :submission, :data, :reference

    def initialize(submission, data)
      @submission, @data = submission, data
      @reference = YAML.load_file(File.join(File.dirname(__FILE__), "epri.yaml"))
    end

    def calc!
      run_calc :sanitized, EpriSheet::Sanitizer

      run_calc :transformer, EpriSheet::Primary::Transformer
      run_calc :network, EpriSheet::Primary::Network
      run_calc :ders, EpriSheet::Primary::Ders

      run_calc :impd, EpriSheet::Secondary::Impedance, :phase
      run_calc :pcur, EpriSheet::Secondary::PhaseCurrent
      run_calc :mult, EpriSheet::Secondary::Multipliers
      run_calc_on_phases :pvol, EpriSheet::Secondary::PhaseVoltage

      run_calc :impd, EpriSheet::Secondary::Impedance, :pen
      run_calc :penv, EpriSheet::Secondary::PenVoltage
      run_calc_on_phases :resv, EpriSheet::Secondary::ResultingVoltage
      run_calc_on_phases :load, EpriSheet::Secondary::LoadVoltage

      run_calc :result, EpriSheet::Result
      self
    end

    def fetch(key, default)
      instance_variable_get("@#{key}") || default
    end

    private

    def run_calc_on_phases(*args)
      (1..3).each do |i|
        run_calc(*args, i)
      end
    end

    def run_calc(name, klass, key=nil)
      self.class.class_eval { attr_reader name }
      current = nil
      if key
        current = instance_variable_get("@#{name}") || {}
        current[key] = klass.new(self, key).run
      else
        current = klass.new(self).run
      end

      instance_variable_set("@#{name}", current)
    end
  end
end