require 'spec_helper'

require 'typed_model/model_validations'

module TypedModel
  RSpec.describe ModelValidations do
    let(:klass) do
      Class.new do
        include ModelValidations
      end
    end

    subject { klass.new }

    it 'is valid with no errors' do
      expect(subject).to be_valid
    end

    it 'is invalid with errors' do
      klass.class_eval do
        def validate
          add_error(:foo, 'some error')
        end
      end
      expect(subject).not_to be_valid
    end

    it 'each validation invocation starts with empty errors' do
      klass.class_eval do
        attr_accessor :should_fail

        def validate
          add_error(:foo, 'some error') if should_fail
        end
      end
      subject.should_fail = true
      expect(subject).not_to be_valid
      subject.should_fail = false
      expect(subject).to be_valid
    end

    describe '#assert_not_blank' do
      before do
        klass.class_eval do
          attr_accessor :foo

          def validate
            assert_not_blank(:foo)
          end
        end
      end

      it 'adds error for nil' do
        subject.foo = nil
        subject.valid?
        expect(subject.errors[:foo]).to include(:required)
      end

      it 'adds error for all white-space' do
        subject.foo = '  '
        subject.valid?
        expect(subject.errors[:foo]).to include(:required)
      end
    end

    describe '#assert_timestamp' do
      before do
        klass.class_eval do
          attr_accessor :foo

          def validate
            assert_timestamp(:foo)
          end
        end
      end

      it 'ignores blank' do
        subject.foo = '  '
        subject.valid?
        expect(subject).to be_valid
      end

      it 'parses strings into Time instances' do
        t = Time.parse('2017-10-31T21:21:56-04:00')
        subject.foo = t.iso8601
        expect(subject.valid?).to eq(true)
        expect(subject.foo).to eq(t)
      end

      it 'is valid with Time' do
        t = Time.now
        subject.foo = t
        expect(subject.valid?).to eq(true)
        expect(subject.foo).to eq(t)
      end

      it 'is invalid with unparseable time' do
        subject.foo = 'foo'
        expect(subject.valid?).to eq(false)
      end
    end

    describe 'before_validation blocks' do
      it 'invokes registered callbacks before validation' do
        klass.class_eval do
          before_validation :validate_foo
          before_validation :validate_bar

          def validate_foo
            add_error(:base, :foo)
          end

          def validate_bar
            add_error(:base, :bar)
          end
        end

        expect(subject).not_to be_valid
        expect(subject.errors[:base]).to include(:foo, :bar)
      end

      specify 'callbacks are inheritable' do
        C1 = Class.new do
          include ModelValidations

          before_validation :foo

          def foo
            add_error(:base, :foo)
          end
        end
        C2 = Class.new(C1) do
          before_validation :bar

          def bar
            add_error(:base, :bar)
          end
        end
        C3 = Class.new(C2) do
          before_validation :baz

          def baz
            add_error(:base, :baz)
          end
        end

        c1_instance = C1.new
        c2_instance = C2.new
        c3_instance = C3.new

        expect(c1_instance).not_to be_valid
        expect(c2_instance).not_to be_valid
        expect(c3_instance).not_to be_valid
        expect(c1_instance.errors[:base]).to eq([:foo])
        expect(c2_instance.errors[:base]).to eq([:foo, :bar])
        expect(c3_instance.errors[:base]).to eq([:foo, :bar, :baz])
      end
    end
  end
end

