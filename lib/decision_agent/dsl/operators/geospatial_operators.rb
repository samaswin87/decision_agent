module DecisionAgent
  module Dsl
    module Operators
      # Handles geospatial operators: within_radius, in_polygon
      module GeospatialOperators
        def self.handle(op, actual_value, expected_value, geospatial_cache: nil, geospatial_cache_mutex: nil)
          case op
          when "within_radius"
            # Checks if point is within radius of center point
            point = parse_coordinates(actual_value)
            return false unless point

            params = parse_radius_params(expected_value)
            return false unless params

            # Cache geospatial distance calculations
            distance = get_cached_distance(point, params[:center], geospatial_cache: geospatial_cache, geospatial_cache_mutex: geospatial_cache_mutex)
            distance <= params[:radius]

          when "in_polygon"
            # Checks if point is inside a polygon using ray casting algorithm
            point = parse_coordinates(actual_value)
            return false unless point

            polygon = parse_polygon(expected_value)
            return false unless polygon
            return false if polygon.size < 3 # Need at least 3 vertices

            point_in_polygon?(point, polygon)

          else
            nil # Not handled by this module
          end
        end

        # Parse coordinates from various formats
        def self.parse_coordinates(value)
          case value
          when Hash
            lat = value[:lat] || value["lat"]
            lon = value[:lon] || value["lon"]
            return nil unless lat && lon
            { lat: lat.to_f, lon: lon.to_f }
          when Array
            return nil unless value.size >= 2
            { lat: value[0].to_f, lon: value[1].to_f }
          else
            nil
          end
        end

        # Parse radius parameters
        def self.parse_radius_params(value)
          return nil unless value.is_a?(Hash)

          center = value[:center] || value["center"]
          radius = value[:radius] || value["radius"]
          return nil unless center && radius

          center_coords = parse_coordinates(center)
          return nil unless center_coords

          { center: center_coords, radius: radius.to_f }
        end

        # Parse polygon from various formats
        def self.parse_polygon(value)
          return nil unless value.is_a?(Array)
          return nil if value.empty?

          value.map { |v| parse_coordinates(v) }.compact
        end

        # Get cached distance between two points
        def self.get_cached_distance(point1, point2, geospatial_cache: nil, geospatial_cache_mutex: nil)
          cache = geospatial_cache
          mutex = geospatial_cache_mutex
          if cache.nil? || mutex.nil?
            cache = ConditionEvaluator.instance_variable_get(:@geospatial_cache)
            mutex = ConditionEvaluator.instance_variable_get(:@geospatial_cache_mutex)
          end

          # Create cache key from sorted coordinates
          key = [[point1[:lat], point1[:lon]], [point2[:lat], point2[:lon]]].sort.hash
          cached = cache[key]
          return cached if cached

          mutex.synchronize do
            cache[key] ||= calculate_distance(point1, point2)
          end
        end

        # Calculate distance between two points using Haversine formula
        def self.calculate_distance(point1, point2)
          Helpers::GeospatialHelpers.haversine_distance(point1, point2)
        end

        # Check if point is inside polygon using ray casting algorithm
        def self.point_in_polygon?(point, polygon)
          Helpers::GeospatialHelpers.point_in_polygon?(point, polygon)
        end
      end
    end
  end
end
