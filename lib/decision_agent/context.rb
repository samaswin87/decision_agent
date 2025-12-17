module DecisionAgent
  class Context
    attr_reader :data

    def initialize(data)
      @data = deep_freeze(data.is_a?(Hash) ? data : {})
    end

    def [](key)
      @data[key]
    end

    def fetch(key, default = nil)
      @data.fetch(key, default)
    end

    def key?(key)
      @data.key?(key)
    end

    def to_h
      @data
    end

    def ==(other)
      other.is_a?(Context) && @data == other.data
    end

    private

    def deep_freeze(obj)
      case obj
      when Hash
        obj.transform_values { |v| deep_freeze(v) }.freeze
      when Array
        obj.map { |v| deep_freeze(v) }.freeze
      else
        obj.freeze
      end
    end
  end
end
