# coding: utf-8

require 'hipchat'
require 'minitest/spec'
require 'stoplight'

describe Stoplight::Notifier::HipChat do
  it 'is a class' do
    Stoplight::Notifier::HipChat.must_be_kind_of(Module)
  end

  it 'is a subclass of Base' do
    Stoplight::Notifier::HipChat.must_be(:<, Stoplight::Notifier::Base)
  end

  describe '#formatter' do
    it 'is initially the default' do
      assert_equal(
        Stoplight::Notifier::HipChat.new(nil, nil).formatter,
        Stoplight::Default::FORMATTER)
    end

    it 'reads the formatter' do
      formatter = proc {}
      assert_equal(
        Stoplight::Notifier::HipChat.new(nil, nil, formatter).formatter,
        formatter)
    end
  end

  describe '#hip_chat' do
    it 'reads the HipChat client' do
      hip_chat = HipChat::Client.new('API token')
      Stoplight::Notifier::HipChat.new(hip_chat, nil).hip_chat
        .must_equal(hip_chat)
    end
  end

  describe '#options' do
    it 'is initially the default' do
      Stoplight::Notifier::HipChat.new(nil, nil).options
        .must_equal(Stoplight::Notifier::HipChat::DEFAULT_OPTIONS)
    end

    it 'reads the options' do
      options = { key: :value }
      Stoplight::Notifier::HipChat.new(nil, nil, nil, options).options
        .must_equal(
          Stoplight::Notifier::HipChat::DEFAULT_OPTIONS.merge(options))
    end
  end

  describe '#room' do
    it 'reads the room' do
      room = 'Notifications'
      Stoplight::Notifier::HipChat.new(nil, room).room.must_equal(room)
    end
  end

  describe '#notify' do
    let(:light) { Stoplight::Light.new(name, &code) }
    let(:name) { ('a'..'z').to_a.shuffle.join }
    let(:code) { -> {} }
    let(:from_color) { Stoplight::Color::GREEN }
    let(:to_color) { Stoplight::Color::RED }
    let(:notifier) { Stoplight::Notifier::HipChat.new(hip_chat, room) }
    let(:hip_chat) { MiniTest::Mock.new }
    let(:room) { ('a'..'z').to_a.shuffle.join }

    before do
      hip_chat.expect(:[], hip_chat, [room])
      hip_chat.expect(:send, nil) do |x, y, z|
        x == 'Stoplight' &&
          y.is_a?(String) &&
          z.is_a?(Hash)
      end
    end

    it 'returns the message' do
      error = nil
      notifier.notify(light, from_color, to_color, error).must_equal(
        notifier.formatter.call(light, from_color, to_color, error))
    end

    it 'returns the message with an error' do
      error = ZeroDivisionError.new('divided by 0')
      notifier.notify(light, from_color, to_color, error).must_equal(
        notifier.formatter.call(light, from_color, to_color, error))
    end

    it 'sends the message' do
      error = nil
      notifier.notify(light, from_color, to_color, error)
      hip_chat.verify
    end
  end
end
