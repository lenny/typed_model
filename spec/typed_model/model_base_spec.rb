require 'spec_helper'
require 'typed_model/model_base'

module TypedModel
  RSpec.describe ModelBase do
    let(:klass) do
      Class.new do
        include ModelBase
      end
    end

    describe 'data conversion' do
      let(:address_class) do
        Class.new do
          include ModelBase
          attribute :state
          attribute :zip
        end
      end

      let(:employee_class) do
        a_c = address_class
        Class.new do
          include ModelBase

          attribute :a_boolean, type: :boolean
          attribute :an_integer, type: :integer
          attribute :a_timestamp, type: :timestamp
          attribute :widget1, type: :map
          attribute :address, type: a_c
          attribute :addresses, seq_of: a_c
          attribute :colors, type: :seq
        end
      end

      specify 'data can be converted to object form and back to data' do
        t = Time.parse('2018-10-30 10:46:08')
        data = { a_boolean: true,
                 an_integer: 4,
                 a_timestamp: t,
                 widget1: { foo: 'FOO' },
                 address: { state: 'NY', zip: '11961' },
                 addresses: [{zip: '11111'}, {zip: '22222'}],
                 colors: %w(red white blue) }

        employee = employee_class.new(data)

        expect(employee.a_boolean).to eq(true)
        expect(employee.an_integer).to eq(4)
        expect(employee.a_timestamp).to eq(t)
        expect(employee.widget1).to eq(foo: 'FOO')
        expect(employee.address.state).to eq('NY')
        expect(employee.colors).to eq(%w(red white blue))
        expect(employee.addresses[0].zip).to eq('11111')
        expect(employee.addresses[1].zip).to eq('22222')
        expect(employee.to_data).to eq(data)
      end

      it 'ignores undeclared attributes' do
        klass.class_eval { attribute :foo }
        o = klass.new(foo: 'FOO', bar: 'BAR')
        expect(o.foo).to eq('FOO')
      end

      specify '#to_data excludes nil attributes' do
        klass.class_eval { attribute :foo }
        o = klass.new
        expect(o.to_data.has_key?(:foo)).to eq(false)
      end

      specify '#to_data does not exclude false booleans' do
        klass.class_eval { attribute :foo, type: :boolean }
        o = klass.new
        o.foo = false
        expect(o.to_data[:foo]).to eq(false)
      end

      describe 'supports mapping data keys to alternate attribute names via :mapping_key' do
        example 'attribute :server_errors, seq_of: :string, mapping_key: :errors' do
          klass.class_eval do
            attribute :server_errors, seq_of: :string, mapping_key: :errors
          end
          o = klass.new(errors: %w(one two))
          expect(o.server_errors).to eq(%w(one two))
          expect(o.to_data).to eq(errors: %w(one two))
        end
      end

      it 'supports setting attributes via name or mapping_key' do
        klass.class_eval do
          attribute :server_errors, seq_of: :string, mapping_key: :errors
        end
        by_name = klass.new(server_errors: %w(one two))
        by_key = klass.new(errors: %w(one two))
        expect(by_name.server_errors).to eq(%w(one two))
        expect(by_key.server_errors).to eq(%w(one two))
      end
    end

    specify 'declared attributes are inherited' do
      c1 = Class.new do
        include ModelBase
        attribute :foo
        def self.name; 'C1'; end
      end
      c2 = Class.new(c1) do
        attribute :bar
        def self.name; 'C2'; end
      end
      c3 = Class.new(c2) do
        attribute :baz
        def self.name; 'C3'; end
      end
      expect(c1.declared_attributes.keys).to eq([:foo])
      expect(c2.declared_attributes.keys).to eq([:foo, :bar])
      expect(c3.declared_attributes.keys).to eq([:foo, :bar, :baz])
    end

    specify 'subclass definitions overwrite superclass ones' do
      c1 = Class.new do
        include ModelBase
        attribute :foo, type: :boolean
      end
      c2 = Class.new(c1) do
        attribute :foo, type: :string
      end
      expect(c2.declared_attributes[:foo].attr_type).to eq(:string)
    end

    describe 'validations' do
      let(:address_class) do
        Class.new do
          include ModelBase
          attribute :street, validations: [:required]
        end
      end

      let(:employee_class) do
        a_c = address_class
        Class.new do
          include ModelBase
          attribute :name, type: :string, validations: [:required]
          attribute :primary_address, type: a_c, validations: [:required]
          attribute :alternate_addresses, seq_of: a_c
        end
      end

      let(:valid_attributes) do
        { name: 'somebody',
          primary_address: { street: 'primary street' },
          alternate_addresses: [{ street: 'alternate 1' }, { street: 'alternate 2' }]
        }
      end

      subject do
        employee_class.new(valid_attributes)
      end

      it 'is valid with valid attributes' do
        expect(subject).to be_valid
      end

      it 'applies top level scalar validations' do
        subject.name = ''
        expect(subject).not_to be_valid
      end

      it 'applies top level association validations' do
        subject.primary_address = nil
        expect(subject).not_to be_valid
      end

      it 'applies single-arity association validations' do
        subject.primary_address.street = ''
        expect(subject).not_to be_valid
      end

      it 'applies multi-arity association validations' do
        subject.alternate_addresses[1].street = ''
        expect(subject).not_to be_valid
      end

      describe 'pulls nested association messages up to top level with adjusted path' do
        example 'without mapping key' do
          subject.alternate_addresses[1].street = ''
          expect(subject).not_to be_valid
          expect(subject.errors['alternate_addresses/1/street']).to include(:required)
        end

        example 'with mapping key' do
          a_c = address_class
          mk_class = Class.new do
            include ModelBase
            attribute :addrs, seq_of: a_c, mapping_key: :addresses
          end
          o = mk_class.new(addresses: [{ street: 'ok' }, { street: '' }])
          expect(o).not_to be_valid
          expect(o.errors['addrs/1/street']).to include(:required)
        end
      end

      describe 'custom validations' do
        specify 'can be included by implementing a matching `assert_` method' do
         employee_class.class_eval do
            attribute :name, validations: [:my_validation]

            def assert_my_validation(attr)
              add_error(attr, 'some error')
            end
          end
          o = employee_class.new
          expect(o).not_to be_valid
          expect(o.errors[:name]).to include('some error')
        end

        specify 'Validator instances can be used' do
          validator = Validator.new(:foo) do
            ['some error']
          end
          employee_class.class_eval do
            attribute :name, validations: [validator]
          end
          o = employee_class.new
          expect(o).not_to be_valid
          expect(o.errors[:name]).to include('some error')
        end

        it 'raises error for unrecognized validations' do
          employee_class.class_eval do
            attribute :name, validations: [:foo]
          end
          o = employee_class.new
          expect { o.valid? }.to raise_error(/unrecognized validation/i)
        end
      end
    end

    describe 'supported types are automatically validated' do
      before do
        klass.class_eval do
          attribute :created_at, type: :timestamp
          attribute :an_integer, type: :integer
        end
      end

      subject do
        klass.new(created_at: Time.now, an_integer: 5)
      end

      example ':timestamp' do
        subject.created_at = 'foo'
        expect(subject).not_to be_valid
      end

      example ':integer' do
        subject.an_integer = 'foo'
        expect(subject).not_to be_valid
      end

      specify 'values can be nil' do
        subject = klass.new
        expect(subject).to be_valid
      end
    end

    describe 'type: :seq' do
      let(:widget_class) do
        Class.new do
          include ModelBase
          attribute :name, type: :string, validations: [:required]
        end
      end

      example 'sequence of singular scalar' do
        klass.class_eval do
          attribute :a_seq, seq_of: :string
        end
        o = klass.new(a_seq: %w(a b c))
        expect(o).to be_valid
        expect(o.to_data).to eq(a_seq: %w(a b c))
        o.a_seq << []
        expect(o).not_to be_valid
      end

      example 'sequence of non-primitive type' do
        w_c = widget_class
        klass.class_eval do
          attribute :a_seq, seq_of: w_c
        end
        o = klass.new(a_seq: [{name: 'widget1'}])
        expect(o.a_seq[0].name).to eq('widget1')
        expect(o).to be_valid
        expect(o.to_data).to eq(a_seq: [{name: 'widget1'}])
        o.a_seq[0].name = nil
        expect(o).not_to be_valid
      end
    end

    describe 'type: :map' do
      let(:widget_class) do
        Class.new do
          include ModelBase
          attribute :name, type: :string, validations: [:required]
        end
      end

      describe 'primitive -> primitive' do
        before do
          klass.class_eval do
            attribute :my_map, map_of: [:string, :integer]
          end
        end

        subject { klass.new(my_map: { 'joe' => 1 }) }

        it 'is valid with valid attributes' do
          expect(subject).to be_valid
        end

        it 'validates key' do
          subject.my_map[2] = 'Bill'
          expect(subject).not_to be_valid
          expect(subject.errors['my_map/2']).not_to be_empty
        end

        it 'validates values' do
          subject.my_map['joe'] = true
          expect(subject).not_to be_valid
          expect(subject.errors['my_map/joe']).not_to be_empty
        end
      end

      describe 'primitive -> object' do
        before do
          w_c = widget_class
          klass.class_eval do
            attribute :my_map, map_of: [:string, w_c]
          end
        end

        subject do
          klass.new(my_map: { 'joe' => { name: 'somewidget' } })
        end

        it 'is valid with valid attributes' do
          expect(subject).to be_valid
        end

        it 'validates key' do
          subject.my_map[{}] = { name: 'somethingelse' }
          expect(subject).not_to be_valid
          expect(subject.errors['my_map/keys/{}']).not_to be_empty
        end

        it 'validates values' do
          subject.my_map['joe'].name = ''
          expect(subject).not_to be_valid
          expect(subject.errors['my_map/joe/name']).not_to be_empty
        end
      end

      describe 'with validations' do
        before do
          w_c = widget_class
          klass.class_eval do
            attribute :my_map,
                      map_of: [{type: :string}, {type: w_c, validations: [:required]}],
                      validations: [:required]
          end
        end

        subject do
          klass.new(my_map: { 'joe' => { name: 'somewidget' } })
        end

        it 'is valid with valid attributes' do
          expect(subject).to be_valid
        end

        it 'validates keys' do
          subject.my_map[{}] = 'Bill'
          expect(subject).not_to be_valid
          expect(subject.errors['my_map/keys/{}']).not_to be_empty
        end

        it 'validates values' do
          subject.my_map['joe'] = nil
          expect(subject).not_to be_valid
          expect(subject.errors['my_map/joe']).not_to be_empty
        end

        it 'validates map' do
          subject.my_map = nil
          expect(subject).not_to be_valid
          expect(subject.errors[:my_map]).not_to be_empty
        end

        it 'applies nested validations' do
          subject.my_map['joe'].name = ''
          expect(subject).not_to be_valid
          expect(subject.errors['my_map/joe/name']).not_to be_empty
        end
      end

      describe 'nested maps' do
        before do
          w_c = widget_class
          klass.class_eval do
            category = :string
            widgets_by_name = [:string, w_c]
            attribute :widgets, map_of: [category, widgets_by_name]
          end
        end

        subject do
          klass.new(widgets: {
              'popular' => {
                  'widget1' => { name: 'widget1' }
              }
          })
        end

        it 'is valid with valid attributes' do
          expect(subject).to be_valid
        end

        it 'builds instance from data' do
          expect(subject.widgets['popular']['widget1'].name).to eq('widget1')
        end

        example '#to_data' do
          expect(subject.to_data[:widgets]).to eq('popular' => {
              'widget1' => { name: 'widget1' }
          })
        end
      end
    end
  end
end
