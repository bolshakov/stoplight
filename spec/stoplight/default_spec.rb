# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight::Default do
  it 'is a module' do
    Stoplight::Default.must_be_kind_of(Module)
  end

  describe '::ALLOWED_ERRORS' do
    it 'is an array' do
      Stoplight::Default::ALLOWED_ERRORS.must_be_kind_of(Array)
    end

    it 'contains exception classes' do
      Stoplight::Default::ALLOWED_ERRORS.each do |allowed_error|
        allowed_error.must_be(:<, Exception)
      end
    end

    it 'is frozen' do
      Stoplight::Default::ALLOWED_ERRORS.frozen?.must_equal(true)
    end
  end

  describe '::DATA_STORE' do
    it 'is a data store' do
      Stoplight::Default::DATA_STORE.must_be_kind_of(Stoplight::DataStore::Base)
    end
  end

  describe '::ERROR_NOTIFIER' do
    it 'is a proc' do
      assert_kind_of(Proc, Stoplight::Default::ERROR_NOTIFIER)
    end

    it 'has an arity of 1' do
      Stoplight::Default::ERROR_NOTIFIER.arity.must_equal(1)
    end
  end

  describe '::FALLBACK' do
    it 'is nil' do
      Stoplight::Default::FALLBACK.must_equal(nil)
    end
  end

  describe '::FORMATTER' do
    it 'is a proc' do
      assert_kind_of(Proc, Stoplight::Default::FORMATTER)
    end

    it 'has the same arity as #notify' do
      notify = Stoplight::Notifier::Base.new.method(:notify)
      Stoplight::Default::FORMATTER.arity.must_equal(notify.arity)
    end
  end

  describe '::NOTIFIERS' do
    it 'is an array' do
      Stoplight::Default::NOTIFIERS.must_be_kind_of(Array)
    end

    it 'contains notifiers' do
      Stoplight::Default::NOTIFIERS.each do |notifier|
        notifier.must_be_kind_of(Stoplight::Notifier::Base)
      end
    end

    it 'is frozen' do
      Stoplight::Default::NOTIFIERS.frozen?.must_equal(true)
    end
  end

  describe '::THRESHOLD' do
    it 'is an integer' do
      Stoplight::Default::THRESHOLD.must_be_kind_of(Fixnum)
    end
  end

  describe '::TIMEOUT' do
    it 'is a float' do
      Stoplight::Default::TIMEOUT.must_be_kind_of(Float)
    end
  end
end
