require 'typed_model/validators'

module TypedModel
  class Validator
    class << self
      def build(arg)
        return arg if arg.respond_to?(:validate) && arg.respond_to?(:name)
        raise "failed to create validator from '#{arg}'" unless arg.is_a?(Symbol)
        raise "Unrecognized validation '#{arg}'" unless Validators.recognized?(arg)
        new_builtin_validator(arg)
      end

      def from_primitive(t)
        new(t) do |v|
          errors = []
          if !v.nil? && (msg = send(:"assert_#{t}", v))
            errors << msg
          end
          errors
        end
      end

      private

      def new_builtin_validator(sym)
        new(sym) do |v|
          errors = []
          if (msg = Validators.validate(sym, v))
            errors << msg
          end
          errors
        end
      end
    end

    attr_reader :name, :f

    def initialize(name, &blk)
      @name = name
      @f = blk
    end

    def validate(value)
      f.call(value)
    end
  end
end

