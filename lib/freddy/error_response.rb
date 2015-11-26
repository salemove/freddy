class Freddy
  class ErrorResponse < StandardError
    DEFAULT_ERROR_MESSAGE = 'Use #response to get the error response'

    attr_reader :response

    def initialize(response)
      @response = response
      super(format_message(response) || DEFAULT_ERROR_MESSAGE)
    end

    private

    def format_message(response)
      return unless response.is_a?(Hash)

      message = [response[:error], response[:message]].compact.join(': ')
      message.empty? ? nil : message
    end
  end
end
