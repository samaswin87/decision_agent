module DecisionAgent
  module Dsl
    module Helpers
      # Geospatial helper methods for ConditionEvaluator
      module GeospatialHelpers
        def self.parse_coordinates(value)
          case value
          when Hash
            lat = value["lat"] || value[:lat] || value["latitude"] || value[:latitude]
            lon = value["lon"] || value[:lon] || value["lng"] || value[:lng] ||
                  value["longitude"] || value[:longitude]
            return nil unless lat && lon

            { lat: lat.to_f, lon: lon.to_f }
          when Array
            return nil unless value.size == 2

            { lat: value[0].to_f, lon: value[1].to_f }
          end
        end

        def self.parse_radius_params(value, parse_coordinates:)
          return nil unless value.is_a?(Hash)

          center_data = value["center"] || value[:center]
          radius = value["radius"] || value[:radius]

          return nil unless center_data && radius

          center = parse_coordinates.call(center_data)
          return nil unless center

          { center: center, radius: radius.to_f }
        end

        def self.parse_polygon(value, parse_coordinates:)
          return nil unless value.is_a?(Array)

          value.map { |vertex| parse_coordinates.call(vertex) }.compact
        end

        def self.haversine_distance(point1, point2)
          earth_radius_km = 6371.0

          lat1_rad = (point1[:lat] * Math::PI) / 180
          lat2_rad = (point2[:lat] * Math::PI) / 180
          delta_lat = ((point2[:lat] - point1[:lat]) * Math::PI) / 180
          delta_lon = ((point2[:lon] - point1[:lon]) * Math::PI) / 180

          a = (Math.sin(delta_lat / 2)**2) +
              (Math.cos(lat1_rad) * Math.cos(lat2_rad) *
              (Math.sin(delta_lon / 2)**2))

          c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

          earth_radius_km * c
        end

        def self.point_in_polygon?(point, polygon)
          return false if polygon.size < 3

          inside = false
          j = polygon.size - 1

          (0...polygon.size).each do |i|
            xi = polygon[i][:lat]
            yi = polygon[i][:lon]
            xj = polygon[j][:lat]
            yj = polygon[j][:lon]

            intersect = ((yi > point[:lon]) != (yj > point[:lon])) &&
                        (point[:lat] < ((xj - xi) * (point[:lon] - yi) / (yj - yi)) + xi)

            inside = !inside if intersect
            j = i
          end

          inside
        end
      end
    end
  end
end
