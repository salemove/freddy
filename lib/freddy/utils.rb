class Freddy
  class Utils
    def self.format_exception(exception)
      backtrace = exception.backtrace.map do |x|
        x.match(/^(.+?):(\d+)(|:in `(.+)')$/);
        [$1, $2, $4]
      end.join("\n")

      "#{exception.exception}\n#{backtrace}"
    end

    def self.notify(name, message, parameters={})
      return unless defined?(Airbrake)

      Airbrake.notify_or_ignore(
        error_class: name,
        error_message: message,
        cgi_data: ENV.to_hash,
        parameters: parameters
      )
    end

    def self.notify_exception(exception, parameters={})
      return unless defined?(Airbrake)

      Airbrake.notify_or_ignore(exception,
        cgi_data: ENV.to_hash,
        parameters: parameters
      )
    end
  end
end
