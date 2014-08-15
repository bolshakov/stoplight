# coding: utf-8

require 'spec_helper'

describe Stoplight::DataStore::Base do
  subject(:data_store) { described_class.new }

  %w(
    attempts
    clear_attempts
    clear_failures
    delete
    failures
    names
    purge
    record_attempt
    record_failure
    set_state
    set_threshold
    state
    threshold
  ).each do |method|
    it "responds to #{method}" do
      expect(data_store).to respond_to(method)
    end

    it "does not implement #{method}" do
      args = [nil] * data_store.method(method).arity
      expect { data_store.public_send(method, *args) }.to raise_error(
        NotImplementedError)
    end
  end
end
