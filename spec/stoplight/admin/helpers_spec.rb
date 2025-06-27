# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Helpers do
  subject(:helper) { klass.new }

  let(:klass) do
    Class.new do
      include Stoplight::Admin::Helpers
    end
  end

  let(:data_store) { Redis.new }
  let(:settings) { Data.define(:data_store).new(data_store: data_store) }

  before do
    allow(helper).to receive(:settings).and_return(settings)
  end

  describe "#dependencies" do
    it "returns Dependencies" do
      expect(helper.dependencies).to be_an_instance_of(Stoplight::Admin::Dependencies)
    end

    context "with Redis data store" do
      let(:data_store) { instance_double(Stoplight::DataStore::Redis) }

      it "does not raise an error" do
        expect { helper.dependencies }.to_not raise_error
      end
    end

    context "with Memory data store" do
      let(:data_store) { Stoplight::DataStore::Memory.new }

      it "raises an error" do
        expect { helper.dependencies }.to raise_error StandardError
      end
    end
  end
end
