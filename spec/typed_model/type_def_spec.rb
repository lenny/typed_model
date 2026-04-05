# frozen_string_literal: true

require 'spec_helper'
require 'date'
require 'typed_model/type_def'

module TypedModel
  RSpec.describe TypeDef do
    describe '.build' do
      specify 'scalar value is accepted as short for {type: t}' do
        expect(TypeDef.build(:string).value_type).to eq(:string)
      end

      describe 'non-container types are unmanipulated' do
        example 'primitive' do
          expect(TypeDef.build(type: :string).value_type).to eq(:string)
        end

        example 'class type' do
          expect(TypeDef.build(type: Object).value_type).to eq(Object)
        end
      end

      describe 'type: :seq' do
        context 'with :seq_of' do
          specify 'type is replaced with SeqOf' do
            expect(TypeDef.build(seq_of: :string).value_type).to be_instance_of(SeqOf)
          end

          specify 'SeqOf :seq_of' do
            expect(TypeDef.build(seq_of: :string).value_type.spec.value_type).to eq(:string)
          end

          describe 'validations' do
            specify 'sequence validations are placed on outer spec' do
              s = TypeDef.build(seq_of: :string, validations: [:required])
              expect(s.validators.map {|v| v.name.to_s }).to eq(%w(required))
            end

            specify 'seq_of validations are placed on SeqOf' do
              s = TypeDef.build(seq_of: {type: :string, validations: [:required]})
              expect(s.value_type.spec.validators.map {|v| v.name.to_s }).to eq(%w(required))
            end
          end
        end

        context 'without :seq_of' do
          specify 'type left as :seq' do
            expect(TypeDef.build(type: :seq).value_type).to eq(:seq)
          end
        end
      end

      describe 'type: :map' do
        context 'with :map_of' do
          specify 'type is replaced with MapOf' do
            expect(TypeDef.build(map_of: [:string, :string]).value_type).to be_instance_of(MapOf)
          end

          specify ':map_of [t1, t2] is sugar for [{type: t1}, {type: t2}]' do
            s = TypeDef.build(map_of: [:string, :integer])
            expect(s.value_type.key_spec.value_type).to eq(:string)
            expect(s.value_type.value_spec.value_type).to eq(:integer)
          end

          describe 'nested maps are supported' do
            example 'map_of: [:string, { type: :map, map_of: [:string, Object]' do
              s = TypeDef.build(map_of: [:string, { type: :map, map_of: [:string, Object] }])
              expect(s.value_type.key_spec.value_type).to eq(:string)
              expect(s.value_type.value_spec.value_type).to be_instance_of(MapOf)
              expect(s.value_type.value_spec.value_type.key_spec.value_type).to eq(:string)
              expect(s.value_type.value_spec.value_type.value_spec.value_type).to eq(Object)
            end

            example 'map_of: [:string, [:string, :Object]' do
              s = TypeDef.build(map_of: [:string, [:string, Object]])
              expect(s.value_type.key_spec.value_type).to eq(:string)
              expect(s.value_type.value_spec.value_type).to be_instance_of(MapOf)
              expect(s.value_type.value_spec.value_type.key_spec.value_type).to eq(:string)
              expect(s.value_type.value_spec.value_type.value_spec.value_type).to eq(Object)
            end
          end

          describe 'validations' do
            specify 'map validations are placed on outer spec' do
              s = TypeDef.build(map_of: [:string, :integer], validations: [:required])
              expect(s.validators.map {|v| v.name.to_s }).to eq(%w(required))
            end

            specify 'map_of validations are placed on MapOf' do
              map_of = [{ type: :string, validations: [:required] }, { type: :string, validations: [:required] }]
              s = TypeDef.build(map_of: map_of)
              expect(s.value_type.key_spec.validators.map {|v| v.name.to_s }).to eq(%w(required))
              expect(s.value_type.value_spec.validators.map {|v| v.name.to_s }).to eq(%w(required))
            end
          end
        end

        context 'without :map_of' do
          specify 'type left as :map' do
            expect(TypeDef.build(type: :map).value_type).to eq(:map)
          end
        end
      end
    end

    describe '#typecast_value' do
      it 'returns value without type' do
        spec = TypeDef.new(type: nil)
        o = Object.new
        expect(spec.typecast_value(o)).to equal(o)
      end

      it 'delegates to type when it responds to :typecast_value' do
        k = Class.new do
          def self.typecast_value(v)
            "#{v}#{v}"
          end
        end
        spec = TypeDef.new(type: k)
        expect(spec.typecast_value('foo')).to eq('foofoo')
      end

      it 'casts supported/primitive types (via Types)' do
        spec = TypeDef.new(type: :string)
        expect(spec.typecast_value(false)).to eq('false')
      end

      context 'with Class type' do
        it 'uses :build to instantiate object when type responds to :build' do
          k = Class.new do
            def self.build(v)
              "#{v}#{v}"
            end
          end
          spec = TypeDef.new(type: k)
          expect(spec.typecast_value('foo')).to eq('foofoo')
        end

        it 'falls back to :new for class types' do
          k = Class.new do
            attr_reader :some_attr

            def initialize(v)
              @some_attr = v
            end
          end
          spec = TypeDef.new(type: k)
          expect(spec.typecast_value('foo').some_attr).to eq('foo')
        end
      end

      it 'casts :boolean types correctly with falsey values' do
        spec = TypeDef.new(type: :boolean)
        expect(spec.typecast_value('false')).to eq(false)
        expect(spec.typecast_value(false)).to eq(false)
        expect(spec.typecast_value('true')).to eq(true)
      end

      context 'with Class type' do
        it 'returns nil given nil' do
          spec = TypeDef.new(type: Object)
          expect(spec.typecast_value(nil)).to be_nil
        end
      end

      it 'raises error for unrecognized type' do
        spec = TypeDef.new(type: true)
        expect { spec.typecast_value('test') }.to raise_error(/unrecognized type/i)
      end
    end

    describe 'validate' do
      it 'handles DateTime <=> nil without error' do
        spec = TypeDef.build(type: :timestamp)
        errors = TypedModel::Errors.new
        spec.validate(DateTime.now, errors, :ts)
        expect(errors).to be_empty
      end
    end
  end
end
