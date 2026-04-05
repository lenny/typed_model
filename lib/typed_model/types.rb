require 'set'

module TypedModel

  # Supported Types/Type coercion
  #
  # Type checking methods (e.g. `boolean`, `integer`, etc..) should return
  # value of type if "reasonably" coercible, otherwise nil.
  #
  # "Reasonable" = reasonable valid over the wire data for type. E.g. String 'true'
  # is reasonable for a declared :boolean. Likewise, boolean is reasonable
  # for declared string, but Hash not so much.
  #
  #
  class Types
    PRIMITIVE_CLASSES = Set.new([String, TrueClass, FalseClass, Integer, Float])

    class << self
      def recognized?(t)
        respond_to?(t)
      end

      def typecast(sym, value)
        type_casted = send(sym, value)
        type_casted.nil? ? value : type_casted
      end

      def timestamp(v)
        if v.respond_to?(:monday?)
          v
        else
          Time.parse(v)
        end
      rescue StandardError
        nil
      end

      def boolean(v)
        case v
        when 'true', true
          true
        when 'false', false
          false
        end
      end

      def integer(v)
        Integer(v)
      rescue StandardError
        nil
      end

      def map(v)
        maplike?(v) ? v : nil
      end

      def seq(v)
        return nil if v.nil?
        return v if v.is_a?(Array)
        return v.to_a if v.respond_to?(:to_a) && !maplike?(v)
        nil
      end

      def string(v)
        primitive?(v) ? v.to_s : nil
      end

      private

      def maplike?(v)
        v.respond_to?(:each_pair)
      end

      def primitive?(v)
        PRIMITIVE_CLASSES.include?(v.class)
      end
    end
  end
end
