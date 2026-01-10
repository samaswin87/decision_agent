# Request/Response helpers for Rack applications
# Provides Sinatra-like convenience methods

require "rack"
require "rack/utils"
require "uri"

module DecisionAgent
  module Web
    module RackRequestHelpers
      # Context object that provides Sinatra-like methods in route handlers
      class RequestContext
        attr_reader :env, :request, :response_status, :response_headers, :response_body
        attr_accessor :current_user, :current_session

        def initialize(env, route_params = {})
          @env = env
          @request = Rack::Request.new(env)
          @route_params = route_params
          @response_status = 200
          @response_headers = { "Content-Type" => "text/html" }
          @response_body = []
          @halted = false
          @halted_response = nil
          @params_hybrid = nil

          # Merge route params, query params, and body params
          # Convert all keys to symbols for consistency
          route_params_sym = route_params.transform_keys(&:to_sym)
          query_params_sym = query_params.transform_keys(&:to_sym)
          body_params_sym = body_params.transform_keys(&:to_sym)
          @params = route_params_sym.merge(query_params_sym).merge(body_params_sym)
          
          # Handle multipart form data (file uploads)
          content_type_header = @env["CONTENT_TYPE"] || ""
          if content_type_header.include?("multipart/form-data")
            # Rack::Request handles multipart automatically
            multipart_params = @request.params
            multipart_params_sym = multipart_params.transform_keys(&:to_sym)
            @params.merge!(multipart_params_sym)
          end
        end

        def params
          # Return params with support for both symbol and string key access
          @params_with_indifferent_access ||= begin
            hash = @params.dup
            # Add string-key versions for all symbol keys
            @params.each do |k, v|
              hash[k.to_s] = v if k.is_a?(Symbol)
            end
            # Add symbol-key versions for all string keys
            hash.to_a.each do |k, v|
              hash[k.to_sym] = v if k.is_a?(String) && !hash.key?(k.to_sym)
            end
            # Create accessor that checks both
            def hash.[](key)
              super(key.to_sym) || super(key.to_s) || super(key)
            end
            hash
          end
        end

        def status(code)
          @response_status = code
          code
        end

        def content_type(type)
          @response_headers["Content-Type"] = type
        end

        def headers
          @response_headers
        end

        def body(str = nil)
          if str
            @response_body = [str.to_s]
            str
          else
            @response_body
          end
        end

        def json(obj)
          content_type "application/json"
          body(obj.to_json)
        end

        def halt(status_code, body = nil)
          @halted = true
          @response_status = status_code
          if body
            content_type "application/json" if @response_headers["Content-Type"] == "text/html"
            @halted_response = [status_code, @response_headers.dup, [body.to_s]]
          else
            @halted_response = [status_code, @response_headers.dup, []]
          end
        end

        def halted?
          @halted
        end

        def halted_response
          @halted_response
        end

        def send_file(filepath)
          return unless File.exist?(filepath)

          content = File.read(filepath)
          ext = File.extname(filepath).downcase
          mime_types = {
            ".css" => "text/css",
            ".js" => "application/javascript",
            ".html" => "text/html",
            ".json" => "application/json",
            ".xml" => "application/xml",
            ".svg" => "image/svg+xml"
          }
          content_type(mime_types[ext] || "application/octet-stream")
          body(content)
        end

        def script_name
          @request.script_name
        end

        def path_info
          @request.path_info
        end

        def cookies
          @request.cookies
        end

        def to_rack_response
          if @halted && @halted_response
            @halted_response
          else
            # Ensure body is an array
            body_array = @response_body.is_a?(Array) ? @response_body : [@response_body.to_s]
            body_array = [""] if body_array.empty?
            [@response_status, @response_headers.dup, body_array]
          end
        end

        def halted?
          @halted
        end

        private

        def query_params
          @request.params
        end

        def body_params
          return {} unless @env["rack.input"]

          # Read body if content type is JSON or form data
          content_type_header = @env["CONTENT_TYPE"] || ""
          body_input = @env["rack.input"].read
          @env["rack.input"].rewind

          return {} if body_input.nil? || body_input.empty?

          if content_type_header.include?("application/json")
            begin
              parsed = JSON.parse(body_input)
              # Convert string keys to symbol keys for consistency
              parsed.is_a?(Hash) ? parsed.transform_keys(&:to_sym) : parsed
            rescue JSON::ParserError
              {}
            end
          elsif content_type_header.include?("application/x-www-form-urlencoded")
            parsed = Rack::Utils.parse_nested_query(body_input)
            parsed.is_a?(Hash) ? parsed.transform_keys(&:to_sym) : parsed
          elsif content_type_header.include?("multipart/form-data")
            # For multipart, use Rack::Request.params which handles it automatically
            # This will be merged in initialize
            {}
          else
            {}
          end
        end
      end

      # Helper to read request body as string
      def self.read_body(env)
        input = env["rack.input"]
        return "" unless input

        body = input.read
        input.rewind
        body.to_s
      end

      # Helper to parse multipart form data (simplified)
      def self.parse_multipart(env)
        content_type = env["CONTENT_TYPE"]
        return {} unless content_type&.include?("multipart/form-data")

        # Simplified multipart parsing
        # In production, you might want to use Rack::Multipart or similar
        {}
      end
    end
  end
end
