# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Helpers, :redis do
  subject(:helper) { klass.new }

  let(:klass) do
    Class.new do
      include Stoplight::Admin::Helpers
    end
  end

  let(:systems) { [instance_double(Stoplight::Wiring::System, persistent?: true)] }
  let(:settings) { class_double(Stoplight::Admin, systems: systems) }

  before do
    allow(helper).to receive(:settings).and_return(settings)
  end

  describe "#dependencies" do
    it "returns Dependencies" do
      expect(helper.dependencies).to be_an_instance_of(Stoplight::Admin::Dependencies)
    end

    context "with persistent data store" do
      let(:systems) do
        [
          instance_double(Stoplight::Wiring::System, persistent?: true)
        ]
      end

      it "does not raise an error" do
        expect { helper.dependencies }.to_not raise_error
      end
    end

    context "with non-persistent data store" do
      let(:systems) do
        [
          instance_double(Stoplight::Wiring::System, persistent?: false)
        ]
      end

      it "raises an error" do
        expect { helper.dependencies }.to raise_error TypeError, /Stoplight Admin requires a persistent data store/
      end
    end
  end
end
