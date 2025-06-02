module RouteHelpers
  def app
    described_class
  end

  def response_body
    JSON(last_response.body)
  end
end

module Rack
  module Test
    module Methods
      def build_rack_mock_session
        Rack::MockSession.new(app, "localhost")
      end
    end
  end
end
