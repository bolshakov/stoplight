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
    it "returns Dependencies" do
      expect(helper.dependencies(system)).to be_an_instance_of(Stoplight::Admin::Dependencies)
    end
  end
end
