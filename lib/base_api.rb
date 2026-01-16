# Base API class that specific API classes can extend
class BaseApi
  include HTTParty

  # Base error class that specific API error classes can extend
  class Error < StandardError
    attr_reader :code, :reasons, :default_message, :request_id

    # Subclasses can override this message, in case they want to customize a
    # default error message, when no message is provided.
    DEFAULT_MESSAGE = "#{self.class.name} request failed"

    def initialize(message, metadata = {})
      message ||= DEFAULT_MESSAGE
      super(message)

      @code = metadata[:code]
      @reasons = metadata[:reasons]
    end
  end
end
