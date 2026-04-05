module TypedModel
  class MapOf
    attr_reader :key_spec, :value_spec

    def initialize(key_spec, val_spec)
      @key_spec = key_spec
      @value_spec = val_spec
    end

    def typecast_value(values)
      values&.each_with_object({}) do |(k, v), h|
        h[key_spec.typecast_value(k)] = value_spec.typecast_value(v)
      end
    end

    def to_data(value)
      value.each_with_object({}) do |(k, v), h|
        h[key_spec.to_data(k)] = value_spec.to_data(v)
      end
    end

    def validate(value, errors, key_prefix)
      value&.each_pair do |k, v|
        key_spec.validate(k, errors, "#{key_prefix}/keys/#{k}")
        value_spec.validate(v, errors, "#{key_prefix}/#{k}")
      end
    end
  end
end
