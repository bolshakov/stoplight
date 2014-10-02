# coding: utf-8

require 'spec_helper'

describe Stoplight::DataStore::Base do
  subject(:data_store) { described_class.new }

  %w(
    names
    clear_stale
    clear
    sync
    greenify
    green?
    yellow?
    red?
    get_color
    get_attempts
    record_attempt
    clear_attempts
    get_failures
    record_failure
    clear_failures
    get_state
    set_state
    clear_state
    get_threshold
    set_threshold
    clear_threshold
    get_timeout
    set_timeout
    clear_timeout
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
