require 'typed_model/types'

module TypedModel
  module Validators
    module_function

    def recognized?(sym)
      respond_to?(:"assert_#{sym}")
    end

    def validate(sym, value)
      method_name = :"assert_#{sym}"
      raise "Unrecognized validation '#{sym}'" unless respond_to?(method_name)
      send(method_name, value)
    end

    def assert_timestamp(v)
      :invalid if Types.timestamp(v).nil?
    end

    def assert_required(v)
      :required if v.nil? || (v.respond_to?(:empty?) && v.empty?)
    end

    # Checks that value contains at least one non-whitespace character.
    # Semantically different from assert_required which only checks empty/nil.
    def assert_not_blank(v)
      :required unless /\S/.match?(v.to_s)
    end

    def assert_not_nil(v)
      :required_not_nil if v.nil?
    end

    def assert_string(v)
      :invalid if Types.string(v).nil?
    end

    def assert_integer(v)
      :invalid if Types.integer(v).nil?
    end
  end
end

