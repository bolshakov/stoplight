# coding: utf-8

require 'spec_helper'
require 'fakeredis'

describe Stoplight::DataStore::Redis do
  it_behaves_like 'a data store'
end
