# frozen_string_literal: true

RSpec.shared_examples "Stoplight::DataStore::Base#record_failure" do
  it "returns the number of failures" do
    expect(data_store.record_failure(config, failure)).to eql(1)
  end

  context "when there is an error" do
    before do
      data_store.record_failure(config, failure)
    end

    it "persists the failure" do
      expect(data_store.get_failures(config)).to eq([failure])
    end
  end

  context "when there is are several errors" do
    before do
      data_store.record_failure(config, failure)
      data_store.record_failure(config, other)
    end

    it "stores more recent failures at the head" do
      expect(data_store.get_failures(config)).to eq([other, failure])
    end
  end

  shared_examples "with_threshold" do
    context "when the number of errors is bigger then threshold" do
      let(:config) { super().with(threshold: 1) }

      before do
        data_store.record_failure(config, failure)
      end

      it "limits the number of stored failures" do
        expect do
          data_store.record_failure(config, other)
        end.to change { data_store.get_failures(config) }
          .from([failure])
          .to([other])
      end
    end
  end

  it_behaves_like "with_threshold"

  context "with window_size" do
    let(:window_size) { 3600 }

    let(:config) { super().with(window_size: window_size) }

    context "when error is outside of the window" do
      let(:older_failure) { Stoplight::Failure.new("class", "message 3", Time.new - window_size - 1) }

      it "stores failures only withing window length" do
        data_store.record_failure(config, failure)
        data_store.record_failure(config, other)
        data_store.record_failure(config, older_failure)

        expect(data_store.get_failures(config)).to eq([other, failure])
      end
    end

    it_behaves_like "with_threshold"
  end
end
