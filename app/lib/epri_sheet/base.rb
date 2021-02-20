module EpriSheet
  class Base
    attr_reader :epri, :args

    def initialize(instance, key=nil)
      @epri = instance
      @key = key
    end

    def pd
      @epri.sanitized.data
    end

    def ref
      @epri.reference
    end

    def transformer
      @epri.fetch(:transformer, {})
    end

    def network
      @epri.fetch(:network, {})
    end

    def ders
      @epri.fetch(:ders, [])
    end

    def run
      perform
      self
    end

    protected

    def perform
      calculate :data
    end

    def calculate_data
    end

    private

    def cache(name)
      self.class.class_eval { attr_reader :sanitized }
      @sanitized = pd[name]
    end

    def calculate(name)
      self.class.class_eval { attr_reader name }
      instance_variable_set("@#{name}", send("calculate_#{name}"))
    end
  end
end