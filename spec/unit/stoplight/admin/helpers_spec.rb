# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Helpers, :redis do
  subject(:helper) { klass.new }

  let(:klass) do
    Class.new do
      include Stoplight::Admin::Helpers
    end
  end

  let(:systems) { [system] }
  let(:system) { instance_double(Stoplight::Wiring::System, persistent?: true, __stoplight__storage: storage) }
  let(:storage) { instance_double(Stoplight::Wiring::System::Storage) }
  let(:settings) { class_double(Stoplight::Admin, systems: systems) }

  before do
    allow(helper).to receive(:settings).and_return(settings)
  end

  describe "#dependencies" do
    before { allow(helper).to receive(:current_system).and_return(system) }

    it "returns Dependencies for the current system" do
      expect(Stoplight::Admin::Dependencies).to receive(:new).with(system:).and_call_original

      expect(helper.dependencies).to be_an_instance_of(Stoplight::Admin::Dependencies)
    end
  end

  describe "#show_system_switcher?" do
    context "with one system configured" do
      it "returns false" do
        expect(helper.show_system_switcher?).to be false
      end
    end

    context "with more than one system configured" do
      let(:systems) { [system, system] }

      it "returns true" do
        expect(helper.show_system_switcher?).to be true
      end
    end
  end
end
