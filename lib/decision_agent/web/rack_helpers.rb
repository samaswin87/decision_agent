# Rack helpers for framework-agnostic web server
# These helpers provide Sinatra-like convenience methods for pure Rack applications

require "rack"
require "rack/file"
require "uri"

module DecisionAgent
  module Web
    module RackHelpers
      # Simple router for Rack applications
      class Router
        def initialize
          @routes = []
          @before_filters = []
        end

        def get(path, &block)
          add_route("GET", path, block)
        end

        def post(path, &block)
          add_route("POST", path, block)
        end

        def put(path, &block)
          add_route("PUT", path, block)
        end

        def delete(path, &block)
          add_route("DELETE", path, block)
        end

        def options(path, &block)
          add_route("OPTIONS", path, block)
        end

        def before(&block)
          @before_filters << block if block
        end

        def match(env)
          method = env["REQUEST_METHOD"]
          path = env["PATH_INFO"] || "/"
          script_name = env["SCRIPT_NAME"] || ""

          # Remove script_name prefix if present
          if script_name && !script_name.empty? && path.start_with?(script_name)
            path = path[script_name.length..] || "/"
          end

          route = find_route(method, path)
          return nil unless route

          {
            handler: route[:handler],
            params: route[:params],
            before_filters: @before_filters
          }
        end

        private

        def add_route(method, path_pattern, handler)
          # Convert Sinatra-style path patterns to regex
          # Example: "/api/versions/:id" -> /^\/api\/versions\/(?<id>[^\/]+)$/
          # Handle wildcard "*" for catch-all routes
          if path_pattern == "*"
            regex_pattern = ".*"
          else
            regex_pattern = path_pattern
              .gsub(%r{:[^/]+}) { |match| "(?<#{match[1..]}>[^/]+)" }
              .gsub(/\*/, ".*")
          end
          regex = /^#{regex_pattern}$/

          @routes << {
            method: method,
            pattern: regex,
            handler: handler,
            path_pattern: path_pattern
          }
        end

        def find_route(method, path)
          # Try exact match first, then try routes in order
          # More specific routes should be registered first
          @routes.each do |route|
            next unless route[:method] == method || route[:method] == "*"

            match = route[:pattern].match(path)
            next unless match

            params = match.named_captures || {}
            params.transform_keys!(&:to_sym) if params.any?
            return {
              handler: route[:handler],
              params: params
            }
          end
          nil
        end
      end
    end
  end
end
