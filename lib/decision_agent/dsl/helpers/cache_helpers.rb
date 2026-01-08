module DecisionAgent
  module Dsl
    module Helpers
      # Cache management helpers for ConditionEvaluator
      module CacheHelpers
        def self.get_cached_regex(pattern, regex_cache:, regex_cache_mutex:)
          return pattern if pattern.is_a?(Regexp)

          # Fast path: check cache without lock
          cached = regex_cache[pattern]
          return cached if cached

          # Slow path: compile and cache
          regex_cache_mutex.synchronize do
            regex_cache[pattern] ||= Regexp.new(pattern.to_s)
          end
        end

        def self.get_cached_path(key_path, path_cache:, path_cache_mutex:)
          # Fast path: check cache without lock
          cached = path_cache[key_path]
          return cached if cached

          # Slow path: split and cache
          path_cache_mutex.synchronize do
            path_cache[key_path] ||= key_path.to_s.split(".").freeze
          end
        end

        def self.get_cached_date(date_string, date_cache:, date_cache_mutex:, parse_date_fast:)
          # Fast path: check cache without lock
          cached = date_cache[date_string]
          return cached if cached

          # Slow path: parse and cache
          date_cache_mutex.synchronize do
            date_cache[date_string] ||= parse_date_fast.call(date_string)
          end
        end

        def self.get_cached_distance(point1, point2, geospatial_cache:, geospatial_cache_mutex:, haversine_distance:)
          # Round coordinates to 4 decimal places (~11m precision) for cache key
          key = [
            point1[:lat].round(4),
            point1[:lon].round(4),
            point2[:lat].round(4),
            point2[:lon].round(4)
          ].join(",")

          # Fast path: check cache without lock
          cached = geospatial_cache[key]
          return cached if cached

          # Slow path: calculate and cache
          geospatial_cache_mutex.synchronize do
            geospatial_cache[key] ||= haversine_distance.call(point1, point2)
          end
        end

        def self.clear_caches!(regex_cache:, path_cache:, date_cache:, geospatial_cache:, param_cache:)
          regex_cache.clear
          path_cache.clear
          date_cache.clear
          geospatial_cache.clear
          param_cache.clear
        end

        def self.cache_stats(regex_cache:, path_cache:, date_cache:, geospatial_cache:, param_cache:)
          {
            regex: regex_cache.size,
            path: path_cache.size,
            date: date_cache.size,
            geospatial: geospatial_cache.size,
            param: param_cache.size
          }
        end
      end
    end
  end
end
