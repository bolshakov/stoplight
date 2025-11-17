# frozen_string_literal: true

module ExceptionHelpers
  def suppress(*exception_classes)
    yield
  rescue *exception_classes
    # pass
  end
end
