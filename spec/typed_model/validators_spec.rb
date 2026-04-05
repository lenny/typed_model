require 'spec_helper'
require 'typed_model/validators'

module TypedModel
  RSpec.describe Validators do
    describe '.assert_required' do
      it 'returns nil for non-empty value' do
        v = double(empty?: false)
        expect(Validators.assert_required(v)).to be_nil
      end

      it 'returns :required for empty value' do
        v = double(empty?: true)
        expect(Validators.assert_required(v)).to eq(:required)
      end

      it 'returns :required for nil' do
        expect(Validators.assert_required(nil)).to eq(:required)
      end

      it 'returns nil for non-nil value that does not respond to :empty?' do
        expect(Validators.assert_required(Object.new)).to be_nil
      end
    end

    describe '.assert_not_blank' do
      it 'returns :required for nil' do
        expect(Validators.assert_not_blank(nil)).to eq(:required)
      end

      it 'returns :required for empty string' do
        expect(Validators.assert_not_blank('')).to eq(:required)
      end

      it 'returns :required for whitespace-only string' do
        expect(Validators.assert_not_blank('   ')).to eq(:required)
      end

      it 'returns nil for non-blank value' do
        expect(Validators.assert_not_blank('hello')).to be_nil
      end

      it 'returns nil for value with leading/trailing whitespace' do
        expect(Validators.assert_not_blank('  hello  ')).to be_nil
      end
    end

    describe '.assert_not_nil' do
      it 'returns nil for non-empty value' do
        v = double(empty?: false)
        expect(Validators.assert_not_nil(v)).to be_nil
      end

      it 'returns nil for empty value' do
        v = double(empty?: true)
        expect(Validators.assert_not_nil(v)).to be_nil
      end

      it 'returns :required_not_nil for nil' do
        expect(Validators.assert_not_nil(nil)).to eq(:required_not_nil)
      end

      it 'returns nil for non-nil' do
        expect(Validators.assert_not_nil(Object.new)).to be_nil
      end
    end
  end
end
