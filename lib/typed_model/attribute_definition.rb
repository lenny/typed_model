require 'typed_model/types'
require 'typed_model/validators'
require 'typed_model/type_def'

module TypedModel
  class AttributeDefinition
    attr_reader :name, :spec, :model_validations, :mapping_key

    def initialize(name:, type: nil, seq_of: nil, map_of: nil, validations: [], mapping_key: nil)
      @name = name
      @mapping_key = mapping_key
      @model_validations = []
      spec_validations = []
      validations.each do |v|
        if Validators.recognized?(v) || v.respond_to?(:validate)
          spec_validations << v
        else
          model_validations << v
        end
      end
      @spec = TypeDef.build(type:, seq_of:, map_of:, validations: spec_validations)
    end

    def attr_type
      spec.value_type
    end

    def mapping_key
      @mapping_key || name
    end

    def validate(model)
      value = attr_value(model)
      spec.validate(value, model.errors, name)
      model_validations.each do |v|
        method_name = :"assert_#{v}"
        raise "Unrecognized validation '#{v}'" unless model.respond_to?(method_name)
        model.send(method_name, name)
      end
    end

    def to_data(model)
      value = attr_value(model)
      spec.to_data(value) unless value.nil?
    end

    def typecast_value(v)
      spec.typecast_value(v)
    end

    def attr_value(model)
      model.send(name)
    end
  end
end



