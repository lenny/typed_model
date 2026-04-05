module TypedModel
  class SeqOf
    attr_reader :spec

    def initialize(spec)
      @spec = spec
    end

    def typecast_value(values)
      values.map { |v| spec.typecast_value(v) }
    end

    def to_data(values)
      values.map { |v| spec.to_data(v) }
    end

    def validate(value, errors, key_prefix)
      value&.each_with_index do |v, index|
        spec.validate(v, errors, "#{key_prefix}/#{index}")
      end
    end
  end
end
