# coding: utf-8

require 'minitest/spec'
require 'stringio'
require 'stoplight'

describe Stoplight::Light::Runnable do
  subject { Stoplight::Light.new(name, &code) }

  # let(:allowed_errors) { [] }
  let(:code) { -> { code_result } }
  let(:code_result) { random_string }
  # let(:data_store) { Stoplight::DataStore::Memory.new }
  let(:fallback) { -> _ { fallback_result } }
  let(:fallback_result) { random_string }
  let(:name) { random_string }
  # let(:threshold) { random_number }
  # let(:timeout) { random_number }

  let(:failure) do
    Stoplight::Failure.new(error.class.name, error.message, time)
  end
  let(:error) { error_class.new(error_message) }
  let(:error_class) { Class.new(StandardError) }
  let(:error_message) { random_string }
  let(:time) { Time.new }

  def random_number
    rand(1_000_000)
  end

  def random_string
    ('a'..'z').to_a.shuffle.first(8).join
  end

  describe '#color' do
    it 'is initially green' do
      subject.color.must_equal(Stoplight::Color::GREEN)
    end

    it 'is green when locked green' do
      subject.data_store.set_state(subject, Stoplight::State::LOCKED_GREEN)
      subject.color.must_equal(Stoplight::Color::GREEN)
    end

    it 'is red when locked red' do
      subject.data_store.set_state(subject, Stoplight::State::LOCKED_RED)
      subject.color.must_equal(Stoplight::Color::RED)
    end

    it 'is red when there are many failures' do
      subject.threshold.times do
        subject.data_store.record_failure(subject, failure)
      end
      subject.color.must_equal(Stoplight::Color::RED)
    end

    it 'is yellow when the most recent failure is old' do
      (subject.threshold - 1).times do
        subject.data_store.record_failure(subject, failure)
      end
      other = Stoplight::Failure.new(
        error.class.name, error.message, Time.new - subject.timeout)
      subject.data_store.record_failure(subject, other)
      subject.color.must_equal(Stoplight::Color::YELLOW)
    end
  end

  describe '#run' do
    let(:notifiers) { [notifier] }
    let(:notifier) { Stoplight::Notifier::IO.new(io) }
    let(:io) { StringIO.new }

    before do
      subject.with_notifiers(notifiers)
    end

    describe 'when the light is green' do
      before { subject.data_store.clear_failures(subject) }

      it 'runs the code' do
        subject.run.must_equal(code_result)
      end

      describe 'with some failures' do
        before { subject.data_store.record_failure(subject, failure) }

        it 'clears the failures' do
          subject.run
          subject.data_store.get_failures(subject).size.must_equal(0)
        end
      end

      describe 'when the code is failing' do
        let(:code_result) { fail error }

        it 're-raises the error' do
          -> { subject.run }.must_raise(error.class)
        end

        it 'records the failure' do
          subject.data_store.get_failures(subject).size.must_equal(0)
          begin
            subject.run
          rescue error.class
            nil
          end
          subject.data_store.get_failures(subject).size.must_equal(1)
        end

        it 'notifies when transitioning to red' do
          subject.threshold.times do
            io.string.must_equal('')
            begin
              subject.run
            rescue error.class
              nil
            end
          end
          io.string.wont_equal('')
        end

        describe 'when the error is allowed' do
          let(:allowed_errors) { [error.class] }

          before { subject.with_allowed_errors(allowed_errors) }

          it 'does not record the failure' do
            subject.data_store.get_failures(subject).size.must_equal(0)
            begin
              subject.run
            rescue error.class
              nil
            end
            subject.data_store.get_failures(subject).size.must_equal(0)
          end
        end

        describe 'with a fallback' do
          before { subject.with_fallback(&fallback) }

          it 'runs the fallback' do
            subject.run.must_equal(fallback_result)
          end

          it 'passes the error to the fallback' do
            subject.with_fallback do |e|
              e.must_equal(error)
              fallback_result
            end
            subject.run.must_equal(fallback_result)
          end
        end
      end

      describe 'when the data store is failing' do
        let(:data_store) { Object.new }
        let(:error_notifier) { -> _ {} }

        before do
          subject
            .with_data_store(data_store)
            .with_error_notifier(&error_notifier)
        end

        it 'runs the code' do
          subject.run.must_equal(code_result)
        end

        it 'notifies about the error' do
          has_notified = false
          subject.with_error_notifier do |e|
            has_notified = true
            e.must_be_kind_of(NoMethodError)
          end
          subject.run
          has_notified.must_equal(true)
        end
      end
    end

    describe 'when the light is yellow' do
      before do
        (subject.threshold - 1).times do
          subject.data_store.record_failure(subject, failure)
        end

        other = Stoplight::Failure.new(
          error.class.name, error.message, time - subject.timeout)
        subject.data_store.record_failure(subject, other)
      end

      it 'runs the code' do
        subject.run.must_equal(code_result)
      end

      it 'notifies when transitioning to green' do
        io.string.must_equal('')
        subject.run
        io.string.wont_equal('')
      end
    end

    describe 'when the light is red' do
      before do
        subject.threshold.times do
          subject.data_store.record_failure(subject, failure)
        end
      end

      it 'raises an error' do
        -> { subject.run }.must_raise(Stoplight::Error::RedLight)
      end

      it 'uses the name as the error message' do
        e =
          begin
            subject.run
          rescue Stoplight::Error::RedLight => e
            e
          end
        e.message.must_equal(subject.name)
      end

      describe 'with a fallback' do
        before { subject.with_fallback(&fallback) }

        it 'runs the fallback' do
          subject.run.must_equal(fallback_result)
        end

        it 'does not pass anything to the fallback' do
          subject.with_fallback do |e|
            e.must_equal(nil)
            fallback_result
          end
          subject.run.must_equal(fallback_result)
        end
      end
    end
  end
end
