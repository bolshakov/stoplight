# frozen_string_literal: true

module ExceptionHelpers
  def suppress(*exception_classes)
    yield
  rescue Exception => e # rubocop:disable Lint/RescueException
    raise unless exception_classes.any? { |cls| e.is_a?(cls) }
  end
end
