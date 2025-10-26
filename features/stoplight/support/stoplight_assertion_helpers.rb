# frozen_string_literal: true

module StoplightAssertionHelpers
  def expect_error(error, table)
    table.rows_hash.each_pair do |key, value|
      case key
      when "Type"
        exception_class = Object.const_get(value)
        expect(error)
          .to be_kind_of(exception_class),
            "Expected exception to be of type #{value}, but got #{error.inspect}"
      when "Message"
        expect(error.message)
          .to eq(value),
            "Expected exception message to be '#{value}', but got '#{error.message}'"
      else
        raise ArgumentError, "Unknown key: #{key}"
      end
    end
  end
end
