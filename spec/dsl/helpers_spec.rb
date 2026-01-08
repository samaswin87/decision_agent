require "spec_helper"

RSpec.describe DecisionAgent::Dsl::Helpers do
  describe "CacheHelpers" do
    let(:regex_cache) { {} }
    let(:regex_cache_mutex) { Mutex.new }
    let(:path_cache) { {} }
    let(:path_cache_mutex) { Mutex.new }
    let(:date_cache) { {} }
    let(:date_cache_mutex) { Mutex.new }
    let(:geospatial_cache) { {} }
    let(:geospatial_cache_mutex) { Mutex.new }
    let(:param_cache) { {} }
    let(:param_cache_mutex) { Mutex.new }

    describe ".get_cached_regex" do
      it "returns regexp if already a regexp" do
        regex = /test/
        result = described_class::CacheHelpers.get_cached_regex(
          regex,
          regex_cache: regex_cache,
          regex_cache_mutex: regex_cache_mutex
        )
        expect(result).to eq(regex)
      end

      it "compiles and caches string pattern" do
        pattern = "test.*pattern"
        result = described_class::CacheHelpers.get_cached_regex(
          pattern,
          regex_cache: regex_cache,
          regex_cache_mutex: regex_cache_mutex
        )
        expect(result).to be_a(Regexp)
        expect(result.source).to eq(pattern)
        expect(regex_cache[pattern]).to eq(result)
      end

      it "returns cached regex on second call" do
        pattern = "test.*pattern"
        first = described_class::CacheHelpers.get_cached_regex(
          pattern,
          regex_cache: regex_cache,
          regex_cache_mutex: regex_cache_mutex
        )
        second = described_class::CacheHelpers.get_cached_regex(
          pattern,
          regex_cache: regex_cache,
          regex_cache_mutex: regex_cache_mutex
        )
        expect(first).to eq(second)
        expect(regex_cache.size).to eq(1)
      end
    end

    describe ".get_cached_path" do
      it "splits and caches path string" do
        key_path = "user.profile.name"
        result = described_class::CacheHelpers.get_cached_path(
          key_path,
          path_cache: path_cache,
          path_cache_mutex: path_cache_mutex
        )
        expect(result).to eq(%w[user profile name])
        expect(result).to be_frozen
        expect(path_cache[key_path]).to eq(result)
      end

      it "returns cached path on second call" do
        key_path = "user.profile.name"
        first = described_class::CacheHelpers.get_cached_path(
          key_path,
          path_cache: path_cache,
          path_cache_mutex: path_cache_mutex
        )
        second = described_class::CacheHelpers.get_cached_path(
          key_path,
          path_cache: path_cache,
          path_cache_mutex: path_cache_mutex
        )
        expect(first).to eq(second)
        expect(path_cache.size).to eq(1)
      end
    end

    describe ".get_cached_date" do
      let(:parse_date_fast) { ->(str) { Time.parse(str) } }

      it "parses and caches date string" do
        date_string = "2024-01-01"
        result = described_class::CacheHelpers.get_cached_date(
          date_string,
          date_cache: date_cache,
          date_cache_mutex: date_cache_mutex,
          parse_date_fast: parse_date_fast
        )
        expect(result).to be_a(Time)
        expect(date_cache[date_string]).to eq(result)
      end

      it "returns cached date on second call" do
        date_string = "2024-01-01"
        first = described_class::CacheHelpers.get_cached_date(
          date_string,
          date_cache: date_cache,
          date_cache_mutex: date_cache_mutex,
          parse_date_fast: parse_date_fast
        )
        second = described_class::CacheHelpers.get_cached_date(
          date_string,
          date_cache: date_cache,
          date_cache_mutex: date_cache_mutex,
          parse_date_fast: parse_date_fast
        )
        expect(first).to eq(second)
        expect(date_cache.size).to eq(1)
      end
    end

    describe ".get_cached_distance" do
      let(:haversine_distance) { ->(_p1, _p2) { 10.5 } }
      let(:point1) { { lat: 37.7749, lon: -122.4194 } }
      let(:point2) { { lat: 37.7750, lon: -122.4195 } }

      it "calculates and caches distance" do
        result = described_class::CacheHelpers.get_cached_distance(
          point1, point2,
          geospatial_cache: geospatial_cache,
          geospatial_cache_mutex: geospatial_cache_mutex,
          haversine_distance: haversine_distance
        )
        expect(result).to eq(10.5)
        expect(geospatial_cache).not_to be_empty
      end

      it "returns cached distance on second call" do
        first = described_class::CacheHelpers.get_cached_distance(
          point1, point2,
          geospatial_cache: geospatial_cache,
          geospatial_cache_mutex: geospatial_cache_mutex,
          haversine_distance: haversine_distance
        )
        second = described_class::CacheHelpers.get_cached_distance(
          point1, point2,
          geospatial_cache: geospatial_cache,
          geospatial_cache_mutex: geospatial_cache_mutex,
          haversine_distance: haversine_distance
        )
        expect(first).to eq(second)
      end
    end

    describe ".clear_caches!" do
      it "clears all caches" do
        regex_cache["test"] = /test/
        path_cache["test"] = ["test"]
        date_cache["test"] = Time.now
        geospatial_cache["test"] = 10.5
        param_cache["test"] = { min: 1, max: 10 }

        described_class::CacheHelpers.clear_caches!(
          regex_cache: regex_cache,
          path_cache: path_cache,
          date_cache: date_cache,
          geospatial_cache: geospatial_cache,
          param_cache: param_cache
        )

        expect(regex_cache).to be_empty
        expect(path_cache).to be_empty
        expect(date_cache).to be_empty
        expect(geospatial_cache).to be_empty
        expect(param_cache).to be_empty
      end
    end

    describe ".cache_stats" do
      it "returns cache statistics" do
        regex_cache["test1"] = /test1/
        path_cache["test2"] = ["test2"]
        date_cache["test3"] = Time.now
        geospatial_cache["test4"] = 10.5
        param_cache["test5"] = { min: 1 }

        stats = described_class::CacheHelpers.cache_stats(
          regex_cache: regex_cache,
          path_cache: path_cache,
          date_cache: date_cache,
          geospatial_cache: geospatial_cache,
          param_cache: param_cache
        )

        expect(stats).to eq({
                              regex: 1,
                              path: 1,
                              date: 1,
                              geospatial: 1,
                              param: 1
                            })
      end
    end
  end

  describe "DateHelpers" do
    describe ".parse_date_fast" do
      it "parses ISO8601 date format" do
        result = described_class::DateHelpers.parse_date_fast("2024-01-15")
        expect(result).to be_a(Time)
        expect(result.year).to eq(2024)
        expect(result.month).to eq(1)
        expect(result.day).to eq(15)
      end

      it "parses ISO8601 datetime format" do
        result = described_class::DateHelpers.parse_date_fast("2024-01-15T14:30:00")
        expect(result).to be_a(Time)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
      end

      it "parses ISO8601 datetime with timezone" do
        result = described_class::DateHelpers.parse_date_fast("2024-01-15T14:30:00Z")
        expect(result).to be_a(Time)
      end

      it "falls back to Time.parse for other formats" do
        result = described_class::DateHelpers.parse_date_fast("January 15, 2024")
        expect(result).to be_a(Time)
      end

      it "returns nil for invalid date string" do
        result = described_class::DateHelpers.parse_date_fast("invalid-date")
        expect(result).to be_nil
      end

      it "returns nil for non-string input" do
        result = described_class::DateHelpers.parse_date_fast(123)
        expect(result).to be_nil
      end
    end

    describe ".parse_date" do
      let(:get_cached_date) { ->(str) { Time.parse(str) } }

      it "returns Time object as-is" do
        time = Time.now
        result = described_class::DateHelpers.parse_date(time, get_cached_date: get_cached_date)
        expect(result).to eq(time)
      end

      it "returns Date object as-is" do
        date = Date.today
        result = described_class::DateHelpers.parse_date(date, get_cached_date: get_cached_date)
        expect(result).to eq(date)
      end

      it "parses string using get_cached_date" do
        result = described_class::DateHelpers.parse_date("2024-01-15", get_cached_date: get_cached_date)
        expect(result).to be_a(Time)
      end

      it "returns nil for invalid input" do
        result = described_class::DateHelpers.parse_date(123, get_cached_date: get_cached_date)
        expect(result).to be_nil
      end
    end

    describe ".compare_dates" do
      let(:parse_date) do
        lambda do |val|
          return val if val.is_a?(Time) || val.is_a?(Date) || val.is_a?(DateTime)

          begin
            Time.parse(val.to_s)
          rescue ArgumentError
            nil
          end
        end
      end

      it "compares Time objects directly" do
        date1 = Time.new(2024, 1, 1)
        date2 = Time.new(2024, 1, 2)
        result = described_class::DateHelpers.compare_dates(
          date1, date2, :<, parse_date: parse_date
        )
        expect(result).to be true
      end

      it "parses and compares string dates" do
        result = described_class::DateHelpers.compare_dates(
          "2024-01-01", "2024-01-02", :<, parse_date: parse_date
        )
        expect(result).to be true
      end

      it "returns false if parsing fails" do
        result = described_class::DateHelpers.compare_dates(
          "invalid", "2024-01-02", :<, parse_date: parse_date
        )
        expect(result).to be false
      end

      it "returns false if either value is nil" do
        result = described_class::DateHelpers.compare_dates(
          nil, Time.now, :<, parse_date: parse_date
        )
        expect(result).to be false
      end
    end

    describe ".normalize_day_of_week" do
      it "normalizes numeric day (0-6)" do
        expect(described_class::DateHelpers.normalize_day_of_week(0)).to eq(0)
        expect(described_class::DateHelpers.normalize_day_of_week(6)).to eq(6)
      end

      it "normalizes numeric day with modulo" do
        expect(described_class::DateHelpers.normalize_day_of_week(7)).to eq(0)
        expect(described_class::DateHelpers.normalize_day_of_week(14)).to eq(0)
      end

      it "normalizes day name (full)" do
        expect(described_class::DateHelpers.normalize_day_of_week("sunday")).to eq(0)
        expect(described_class::DateHelpers.normalize_day_of_week("monday")).to eq(1)
        expect(described_class::DateHelpers.normalize_day_of_week("saturday")).to eq(6)
      end

      it "normalizes day name (abbreviated)" do
        expect(described_class::DateHelpers.normalize_day_of_week("sun")).to eq(0)
        expect(described_class::DateHelpers.normalize_day_of_week("mon")).to eq(1)
        expect(described_class::DateHelpers.normalize_day_of_week("sat")).to eq(6)
      end

      it "is case-insensitive" do
        expect(described_class::DateHelpers.normalize_day_of_week("SUNDAY")).to eq(0)
        expect(described_class::DateHelpers.normalize_day_of_week("Monday")).to eq(1)
      end

      it "returns nil for invalid day name" do
        expect(described_class::DateHelpers.normalize_day_of_week("invalid")).to be_nil
      end
    end
  end

  describe "GeospatialHelpers" do
    describe ".parse_coordinates" do
      it "parses hash with lat/lon keys" do
        result = described_class::GeospatialHelpers.parse_coordinates({ "lat" => 37.7749, "lon" => -122.4194 })
        expect(result).to eq({ lat: 37.7749, lon: -122.4194 })
      end

      it "parses hash with symbol keys" do
        result = described_class::GeospatialHelpers.parse_coordinates({ lat: 37.7749, lon: -122.4194 })
        expect(result).to eq({ lat: 37.7749, lon: -122.4194 })
      end

      it "parses hash with latitude/longitude keys" do
        result = described_class::GeospatialHelpers.parse_coordinates({ "latitude" => 37.7749, "longitude" => -122.4194 })
        expect(result).to eq({ lat: 37.7749, lon: -122.4194 })
      end

      it "parses hash with lng key" do
        result = described_class::GeospatialHelpers.parse_coordinates({ "lat" => 37.7749, "lng" => -122.4194 })
        expect(result).to eq({ lat: 37.7749, lon: -122.4194 })
      end

      it "parses array with [lat, lon]" do
        result = described_class::GeospatialHelpers.parse_coordinates([37.7749, -122.4194])
        expect(result).to eq({ lat: 37.7749, lon: -122.4194 })
      end

      it "returns nil for invalid hash" do
        result = described_class::GeospatialHelpers.parse_coordinates({ "lat" => 37.7749 })
        expect(result).to be_nil
      end

      it "returns nil for invalid array" do
        result = described_class::GeospatialHelpers.parse_coordinates([37.7749])
        expect(result).to be_nil
      end

      it "returns nil for non-hash/non-array" do
        result = described_class::GeospatialHelpers.parse_coordinates("invalid")
        expect(result).to be_nil
      end
    end

    describe ".parse_radius_params" do
      let(:parse_coordinates) { ->(val) { described_class::GeospatialHelpers.parse_coordinates(val) } }

      it "parses radius parameters" do
        value = { "center" => { "lat" => 37.7749, "lon" => -122.4194 }, "radius" => 10.5 }
        result = described_class::GeospatialHelpers.parse_radius_params(value, parse_coordinates: parse_coordinates)
        expect(result).to eq({
                               center: { lat: 37.7749, lon: -122.4194 },
                               radius: 10.5
                             })
      end

      it "parses with symbol keys" do
        value = { center: { lat: 37.7749, lon: -122.4194 }, radius: 10.5 }
        result = described_class::GeospatialHelpers.parse_radius_params(value, parse_coordinates: parse_coordinates)
        expect(result[:radius]).to eq(10.5)
      end

      it "returns nil for non-hash input" do
        result = described_class::GeospatialHelpers.parse_radius_params("invalid", parse_coordinates: parse_coordinates)
        expect(result).to be_nil
      end

      it "returns nil for missing center" do
        value = { "radius" => 10.5 }
        result = described_class::GeospatialHelpers.parse_radius_params(value, parse_coordinates: parse_coordinates)
        expect(result).to be_nil
      end

      it "returns nil for missing radius" do
        value = { "center" => { "lat" => 37.7749, "lon" => -122.4194 } }
        result = described_class::GeospatialHelpers.parse_radius_params(value, parse_coordinates: parse_coordinates)
        expect(result).to be_nil
      end
    end

    describe ".parse_polygon" do
      let(:parse_coordinates) { ->(val) { described_class::GeospatialHelpers.parse_coordinates(val) } }

      it "parses polygon array" do
        value = [
          { "lat" => 0, "lon" => 0 },
          { "lat" => 0, "lon" => 1 },
          { "lat" => 1, "lon" => 1 }
        ]
        result = described_class::GeospatialHelpers.parse_polygon(value, parse_coordinates: parse_coordinates)
        expect(result.size).to eq(3)
        expect(result[0]).to eq({ lat: 0.0, lon: 0.0 })
      end

      it "filters out invalid coordinates" do
        value = [
          { "lat" => 0, "lon" => 0 },
          { "invalid" => "data" },
          { "lat" => 1, "lon" => 1 }
        ]
        result = described_class::GeospatialHelpers.parse_polygon(value, parse_coordinates: parse_coordinates)
        expect(result.size).to eq(2)
      end

      it "returns nil for non-array input" do
        result = described_class::GeospatialHelpers.parse_polygon("invalid", parse_coordinates: parse_coordinates)
        expect(result).to be_nil
      end
    end

    describe ".haversine_distance" do
      it "calculates distance between two points" do
        point1 = { lat: 37.7749, lon: -122.4194 } # San Francisco
        point2 = { lat: 34.0522, lon: -118.2437 } # Los Angeles
        distance = described_class::GeospatialHelpers.haversine_distance(point1, point2)
        # Distance should be approximately 559 km
        expect(distance).to be_between(550, 570)
      end

      it "returns 0 for same point" do
        point = { lat: 37.7749, lon: -122.4194 }
        distance = described_class::GeospatialHelpers.haversine_distance(point, point)
        expect(distance).to be < 0.1
      end

      it "handles negative coordinates" do
        point1 = { lat: -37.7749, lon: -122.4194 }
        point2 = { lat: -34.0522, lon: -118.2437 }
        distance = described_class::GeospatialHelpers.haversine_distance(point1, point2)
        expect(distance).to be > 0
      end
    end

    describe ".point_in_polygon?" do
      it "returns true for point inside polygon" do
        point = { lat: 0.5, lon: 0.5 }
        polygon = [
          { lat: 0, lon: 0 },
          { lat: 0, lon: 1 },
          { lat: 1, lon: 1 },
          { lat: 1, lon: 0 }
        ]
        result = described_class::GeospatialHelpers.point_in_polygon?(point, polygon)
        expect(result).to be true
      end

      it "returns false for point outside polygon" do
        point = { lat: 2, lon: 2 }
        polygon = [
          { lat: 0, lon: 0 },
          { lat: 0, lon: 1 },
          { lat: 1, lon: 1 },
          { lat: 1, lon: 0 }
        ]
        result = described_class::GeospatialHelpers.point_in_polygon?(point, polygon)
        expect(result).to be false
      end

      it "returns false for polygon with less than 3 vertices" do
        point = { lat: 0.5, lon: 0.5 }
        polygon = [
          { lat: 0, lon: 0 },
          { lat: 1, lon: 1 }
        ]
        result = described_class::GeospatialHelpers.point_in_polygon?(point, polygon)
        expect(result).to be false
      end
    end
  end

  describe "ComparisonHelpers" do
    describe ".compare_percentile_result" do
      it "compares with threshold" do
        result = described_class::ComparisonHelpers.compare_percentile_result(85, { threshold: 80 })
        expect(result).to be true
      end

      it "compares with multiple conditions" do
        result = described_class::ComparisonHelpers.compare_percentile_result(
          85,
          { threshold: 80, gt: 70, lt: 90 }
        )
        expect(result).to be true
      end

      it "returns false if threshold not met" do
        result = described_class::ComparisonHelpers.compare_percentile_result(75, { threshold: 80 })
        expect(result).to be false
      end

      it "handles eq condition" do
        result = described_class::ComparisonHelpers.compare_percentile_result(85, { eq: 85 })
        expect(result).to be true
      end
    end

    describe ".compare_duration_result" do
      it "compares with min and max" do
        result = described_class::ComparisonHelpers.compare_duration_result(5, { min: 1, max: 10 })
        expect(result).to be true
      end

      it "returns false if outside range" do
        result = described_class::ComparisonHelpers.compare_duration_result(15, { min: 1, max: 10 })
        expect(result).to be false
      end

      it "handles gt and lt conditions" do
        result = described_class::ComparisonHelpers.compare_duration_result(5, { gt: 1, lt: 10 })
        expect(result).to be true
      end
    end

    describe ".compare_date_result?" do
      let(:actual) { Time.new(2024, 1, 15) }
      let(:target) { Time.new(2024, 1, 20) }

      it "compares with eq operator" do
        result = described_class::ComparisonHelpers.compare_date_result?(actual, actual, { compare: "eq" })
        expect(result).to be true
      end

      it "compares with lt operator" do
        result = described_class::ComparisonHelpers.compare_date_result?(actual, target, { compare: "lt" })
        expect(result).to be true
      end

      it "compares with gt operator" do
        result = described_class::ComparisonHelpers.compare_date_result?(target, actual, { compare: "gt" })
        expect(result).to be true
      end

      it "compares with gte operator" do
        result = described_class::ComparisonHelpers.compare_date_result?(target, actual, { compare: "gte" })
        expect(result).to be true
      end

      it "compares with lte operator" do
        result = described_class::ComparisonHelpers.compare_date_result?(actual, target, { compare: "lte" })
        expect(result).to be true
      end

      it "handles eq parameter" do
        result = described_class::ComparisonHelpers.compare_date_result?(actual, actual, { eq: true })
        expect(result).to be true
      end

      it "returns false for unknown operator" do
        result = described_class::ComparisonHelpers.compare_date_result?(actual, target, { compare: "unknown" })
        expect(result).to be false
      end
    end

    describe ".compare_moving_window_result" do
      it "compares with threshold" do
        result = described_class::ComparisonHelpers.compare_moving_window_result(85, { threshold: 80 })
        expect(result).to be true
      end

      it "compares with multiple conditions" do
        result = described_class::ComparisonHelpers.compare_moving_window_result(
          85,
          { threshold: 80, gt: 70, lt: 90 }
        )
        expect(result).to be true
      end
    end

    describe ".compare_financial_result" do
      it "compares with threshold" do
        result = described_class::ComparisonHelpers.compare_financial_result(1050, { threshold: 1000 })
        expect(result).to be true
      end

      it "compares with gt and lt" do
        result = described_class::ComparisonHelpers.compare_financial_result(1050, { gt: 1000, lt: 1100 })
        expect(result).to be true
      end
    end

    describe ".compare_numeric_with_hash" do
      it "compares with min" do
        result = described_class::ComparisonHelpers.compare_numeric_with_hash(85, { min: 80 })
        expect(result).to be true
      end

      it "compares with max" do
        result = described_class::ComparisonHelpers.compare_numeric_with_hash(85, { max: 90 })
        expect(result).to be true
      end

      it "compares with gt" do
        result = described_class::ComparisonHelpers.compare_numeric_with_hash(85, { gt: 80 })
        expect(result).to be true
      end

      it "compares with lt" do
        result = described_class::ComparisonHelpers.compare_numeric_with_hash(85, { lt: 90 })
        expect(result).to be true
      end

      it "compares with gte" do
        result = described_class::ComparisonHelpers.compare_numeric_with_hash(85, { gte: 85 })
        expect(result).to be true
      end

      it "compares with lte" do
        result = described_class::ComparisonHelpers.compare_numeric_with_hash(85, { lte: 85 })
        expect(result).to be true
      end

      it "compares with eq" do
        result = described_class::ComparisonHelpers.compare_numeric_with_hash(85, { eq: 85 })
        expect(result).to be true
      end

      it "handles string keys" do
        result = described_class::ComparisonHelpers.compare_numeric_with_hash(85, { "min" => 80 })
        expect(result).to be true
      end

      it "returns false if condition not met" do
        result = described_class::ComparisonHelpers.compare_numeric_with_hash(75, { min: 80 })
        expect(result).to be false
      end

      it "handles multiple conditions" do
        result = described_class::ComparisonHelpers.compare_numeric_with_hash(85, { min: 80, max: 90 })
        expect(result).to be true
      end
    end
  end

  describe "ParameterParsingHelpers" do
    let(:param_cache) { {} }
    let(:param_cache_mutex) { Mutex.new }

    describe ".parse_range" do
      it "parses range from array" do
        result = described_class::ParameterParsingHelpers.parse_range(
          [10, 20],
          param_cache: param_cache,
          param_cache_mutex: param_cache_mutex
        )
        expect(result).to eq({ min: 10, max: 20 })
      end

      it "parses range from hash" do
        result = described_class::ParameterParsingHelpers.parse_range(
          { "min" => 10, "max" => 20 },
          param_cache: param_cache,
          param_cache_mutex: param_cache_mutex
        )
        expect(result).to eq({ min: 10, max: 20 })
      end

      it "caches parsed result" do
        first = described_class::ParameterParsingHelpers.parse_range(
          [10, 20],
          param_cache: param_cache,
          param_cache_mutex: param_cache_mutex
        )
        second = described_class::ParameterParsingHelpers.parse_range(
          [10, 20],
          param_cache: param_cache,
          param_cache_mutex: param_cache_mutex
        )
        expect(first).to eq(second)
        expect(param_cache.size).to eq(1)
      end
    end

    describe ".parse_modulo_params" do
      it "parses modulo params from array" do
        result = described_class::ParameterParsingHelpers.parse_modulo_params(
          [5, 2],
          param_cache: param_cache,
          param_cache_mutex: param_cache_mutex
        )
        expect(result).to eq({ divisor: 5, remainder: 2 })
      end

      it "parses modulo params from hash" do
        result = described_class::ParameterParsingHelpers.parse_modulo_params(
          { "divisor" => 5, "remainder" => 2 },
          param_cache: param_cache,
          param_cache_mutex: param_cache_mutex
        )
        expect(result).to eq({ divisor: 5, remainder: 2 })
      end
    end

    describe ".parse_power_params" do
      it "parses power params" do
        result = described_class::ParameterParsingHelpers.parse_power_params({ "exponent" => 2, "result" => 4 })
        expect(result).to eq({ exponent: 2, result: 4 })
      end

      it "returns nil for missing exponent" do
        result = described_class::ParameterParsingHelpers.parse_power_params({ "result" => 4 })
        expect(result).to be_nil
      end
    end

    describe ".parse_atan2_params" do
      it "parses atan2 params" do
        result = described_class::ParameterParsingHelpers.parse_atan2_params({ "y" => 1, "result" => 0.785 })
        expect(result).to eq({ y: 1, result: 0.785 })
      end
    end

    describe ".parse_gcd_lcm_params" do
      it "parses gcd/lcm params" do
        result = described_class::ParameterParsingHelpers.parse_gcd_lcm_params({ "other" => 12, "result" => 6 })
        expect(result).to eq({ other: 12, result: 6 })
      end
    end

    describe ".parse_percentile_params" do
      it "parses percentile params" do
        result = described_class::ParameterParsingHelpers.parse_percentile_params({
                                                                                    "percentile" => 90,
                                                                                    "threshold" => 85,
                                                                                    "gt" => 80
                                                                                  })
        expect(result).to eq({
                               percentile: 90.0,
                               threshold: 85,
                               gt: 80,
                               lt: nil,
                               gte: nil,
                               lte: nil,
                               eq: nil
                             })
      end

      it "returns nil for invalid percentile" do
        result = described_class::ParameterParsingHelpers.parse_percentile_params({ "percentile" => 150 })
        expect(result).to be_nil
      end
    end
  end

  describe "TemplateHelpers" do
    let(:context_hash) { { user: { name: "John", age: 30 } } }
    let(:get_nested_value) { ->(hash, path) { DecisionAgent::Dsl::Helpers::UtilityHelpers.get_nested_value(hash, path, get_cached_path: ->(p) { p.split(".") }) } }

    describe ".expand_template_value" do
      it "expands template with single placeholder" do
        result = described_class::TemplateHelpers.expand_template_value(
          "Hello {{user.name}}",
          context_hash,
          get_nested_value: get_nested_value
        )
        expect(result).to eq("Hello John")
      end

      it "expands template with multiple placeholders" do
        result = described_class::TemplateHelpers.expand_template_value(
          "{{user.name}} is {{user.age}} years old",
          context_hash,
          get_nested_value: get_nested_value
        )
        expect(result).to eq("John is 30 years old")
      end

      it "returns original value if no placeholders" do
        result = described_class::TemplateHelpers.expand_template_value(
          "Hello World",
          context_hash,
          get_nested_value: get_nested_value
        )
        expect(result).to eq("Hello World")
      end

      it "returns non-string value as-is" do
        result = described_class::TemplateHelpers.expand_template_value(
          123,
          context_hash,
          get_nested_value: get_nested_value
        )
        expect(result).to eq(123)
      end
    end

    describe ".expand_template_params" do
      it "expands all template values in params" do
        params = {
          "name" => "{{user.name}}",
          "age" => "{{user.age}}"
        }
        result = described_class::TemplateHelpers.expand_template_params(
          params,
          context_hash,
          get_nested_value: get_nested_value
        )
        # Template expansion returns strings, not original types
        expect(result).to eq({ "name" => "John", "age" => "30" })
      end

      it "returns empty hash for non-hash input" do
        result = described_class::TemplateHelpers.expand_template_params(
          "invalid",
          context_hash,
          get_nested_value: get_nested_value
        )
        expect(result).to eq({})
      end
    end

    describe ".apply_mapping" do
      it "applies mapping to response data" do
        response_data = { "user_name" => "John", "user_age" => 30 }
        mapping = { "user_name" => "name", "user_age" => "age" }
        result = described_class::TemplateHelpers.apply_mapping(
          response_data,
          mapping,
          get_nested_value: get_nested_value
        )
        expect(result).to eq({ "name" => "John", "age" => 30 })
      end

      it "returns empty hash for non-hash input" do
        result = described_class::TemplateHelpers.apply_mapping(
          "invalid",
          {},
          get_nested_value: get_nested_value
        )
        expect(result).to eq({})
      end
    end
  end

  describe "UtilityHelpers" do
    describe ".get_nested_value" do
      let(:hash) { { user: { profile: { name: "John" } } } }
      let(:get_cached_path) { ->(path) { path.split(".") } }

      it "retrieves nested value with dot notation" do
        result = described_class::UtilityHelpers.get_nested_value(hash, "user.profile.name", get_cached_path: get_cached_path)
        expect(result).to eq("John")
      end

      it "retrieves top-level value" do
        result = described_class::UtilityHelpers.get_nested_value(hash, "user", get_cached_path: get_cached_path)
        expect(result).to eq({ profile: { name: "John" } })
      end

      it "handles symbol keys" do
        result = described_class::UtilityHelpers.get_nested_value(hash, "user", get_cached_path: get_cached_path)
        expect(result).to be_a(Hash)
      end

      it "returns nil for non-existent path" do
        result = described_class::UtilityHelpers.get_nested_value(hash, "user.missing", get_cached_path: get_cached_path)
        expect(result).to be_nil
      end

      it "returns nil for non-hash intermediate value" do
        hash_with_string = { user: "not a hash" }
        result = described_class::UtilityHelpers.get_nested_value(hash_with_string, "user.profile", get_cached_path: get_cached_path)
        expect(result).to be_nil
      end
    end

    describe ".comparable?" do
      it "returns true for numeric values" do
        expect(described_class::UtilityHelpers.comparable?(10, 20.5)).to be true
        expect(described_class::UtilityHelpers.comparable?(10, 20)).to be true
      end

      it "returns true for same string class" do
        expect(described_class::UtilityHelpers.comparable?("a", "b")).to be true
      end

      it "returns false for different types" do
        expect(described_class::UtilityHelpers.comparable?(10, "20")).to be false
      end

      it "returns false for string subclass" do
        # String subclasses are not considered comparable
        expect(described_class::UtilityHelpers.comparable?("a".dup, "b".dup)).to be true
      end
    end

    describe ".epsilon_equal?" do
      it "returns true for equal values" do
        expect(described_class::UtilityHelpers.epsilon_equal?(1.0, 1.0)).to be true
      end

      it "returns true for values within epsilon" do
        expect(described_class::UtilityHelpers.epsilon_equal?(1.0, 1.0 + 1e-11)).to be true
      end

      it "returns false for values outside epsilon" do
        expect(described_class::UtilityHelpers.epsilon_equal?(1.0, 1.1)).to be false
      end

      it "allows custom epsilon" do
        expect(described_class::UtilityHelpers.epsilon_equal?(1.0, 1.01, 0.1)).to be true
      end
    end

    describe ".string_operator?" do
      it "returns true for string values" do
        expect(described_class::UtilityHelpers.string_operator?("a", "b")).to be true
      end

      it "returns false for non-string values" do
        expect(described_class::UtilityHelpers.string_operator?(10, "b")).to be false
        expect(described_class::UtilityHelpers.string_operator?("a", 10)).to be false
      end
    end
  end
end
