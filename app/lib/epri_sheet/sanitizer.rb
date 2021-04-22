# encoding: UTF-8

module EpriSheet
  class Sanitizer < Base
    # used for translating API data to spreadsheet data
    WCT = {
      "CU Cable" => "Cu kábel",
      "AL Cable" => "Al kábel",
      "Air Cable" => "Légkábel",
      "CU Underground Wire" => "Cu vezeték",
      "AL Underground Wire" => "Al vezeték"
    }

    attr_reader :data

    def initialize(instance)
      super
      @sub, @data = instance.submission, instance.data
    end

    def pd
      raise NoMethodError
    end

    def run
      calculate :phase
      calculate :transformer
      calculate :network
      calculate :ders
      calculate :input

      @data = { transformer: @transformer, phase: @phase, network: @network, ders: @ders + [@input] }
      self
    end

    protected

    def calculate_phase
      Hash[@data['phase_asymmmetry'].map{|k,v| [k, v.gsub("%", "").to_f/100]}]
    end

    def calculate_network
      Hash[@data['segments_of_feeder'].map do |k,v|
        v = Hash[v.map{|a,b| [a.gsub(/(_on_)?segment_?/, '').gsub("cable", ""),b]}]
        v = Hash[v].slice("customercount", "length", "material", "type")
        [k.to_i, {material: WCT[v['material']], customers: v['customercount'].to_i, length: v['length'].to_i, type: v['type']}]
      end]
    end

    def calculate_ders
      ders = @data['segments_of_feeder'].map{|k,v| v['DERs'].values}.flatten(1)
      ders += @data['segments_of_feeder'].map{|k,v| (v[k] || {}).slice("DER_capacity", "DER_distance", "DER_connection", "DER_connect2phase")}.reject(&:empty?)
      ders = ders.map{|i| Hash[i.map{|k,v| [k.gsub("DER_", ""), v.gsub(/[^0-9\.]/, '').to_f]}]}
      ders = ders.map.with_index{|i,j| i[:user] = false; i}.reverse
      ders.map.with_index{|r,i| r[:label] = (65+i).chr; r}
    end

    def calculate_input
      input = Hash[@sub.map{|k,v| [k, v.to_s.gsub(/[^0-9\.]/, '').to_f]}]
      input[:user] = true
      input[:label] = (65+@ders.length).chr
      input
    end

    def calculate_transformer
      {
        type: @data['transformer']['type'],
        power: @data['transformer']['capacity'].gsub(/[^0-9]/, '').to_i, # Y23
        position: ref['tapping_positions'][@data['transformer']['feeder_count'].to_i - 1],
        voltage: @data['transformer']['voltage_level'].to_f
      }
    end
  end
end