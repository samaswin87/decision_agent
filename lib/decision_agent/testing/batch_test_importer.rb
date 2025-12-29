require "csv"
require "roo"

module DecisionAgent
  module Testing
    # Imports test scenarios from CSV or Excel files
    class BatchTestImporter
      attr_reader :errors, :warnings

      def initialize
        @errors = []
        @warnings = []
      end

      # Import test scenarios from a CSV file
      # @param file_path [String] Path to CSV file
      # @param options [Hash] Import options
      #   - :context_columns [Array<String>] Column names to use as context (default: all except id, expected_decision, expected_confidence)
      #   - :id_column [String] Column name for test ID (default: 'id')
      #   - :expected_decision_column [String] Column name for expected decision (default: 'expected_decision')
      #   - :expected_confidence_column [String] Column name for expected confidence (default: 'expected_confidence')
      #   - :skip_header [Boolean] Skip first row (default: true)
      #   - :progress_callback [Proc] Callback for progress updates (called with { processed: N, total: M, percentage: X })
      # @return [Array<TestScenario>] Array of test scenarios
      def import_csv(file_path, options = {})
        @errors = []
        @warnings = []

        options = {
          context_columns: nil,
          id_column: "id",
          expected_decision_column: "expected_decision",
          expected_confidence_column: "expected_confidence",
          skip_header: true,
          progress_callback: nil
        }.merge(options)

        scenarios = []
        row_number = 0

        # Count total rows for progress tracking (if callback provided)
        total_rows = nil
        if options[:progress_callback]
          total_rows = count_csv_rows(file_path, options[:skip_header])
        end

        if options[:skip_header]
          CSV.foreach(file_path, headers: true) do |row|
            row_number += 1
            begin
              scenario = parse_csv_row(row, row_number, options)
              scenarios << scenario if scenario
            rescue StandardError => e
              @errors << "Row #{row_number}: #{e.message}"
            end

            # Call progress callback if provided
            if options[:progress_callback] && total_rows
              options[:progress_callback].call(
                processed: row_number,
                total: total_rows,
                percentage: (row_number.to_f / total_rows * 100).round(2)
              )
            end
          end
        else
          # Without headers, we need to use numeric indices
          # This is a simplified case - in practice, users should provide headers
          CSV.foreach(file_path, headers: false) do |row|
            row_number += 1
            begin
              # Convert array to hash with numeric keys
              row_hash = row.each_with_index.to_h { |val, idx| [idx.to_s, val] }
              scenario = parse_hash_row(row_hash, row_number, options.merge(id_column: "0"))
              scenarios << scenario if scenario
            rescue StandardError => e
              @errors << "Row #{row_number}: #{e.message}"
            end

            # Call progress callback if provided
            if options[:progress_callback] && total_rows
              options[:progress_callback].call(
                processed: row_number,
                total: total_rows,
                percentage: (row_number.to_f / total_rows * 100).round(2)
              )
            end
          end
        end

        raise ImportError, "Failed to import: #{@errors.join('; ')}" if @errors.any? && scenarios.empty?

        scenarios
      end

      # Import test scenarios from an Excel file (.xlsx, .xls)
      # @param file_path [String] Path to Excel file
      # @param options [Hash] Import options (same as import_csv)
      #   - :sheet [String|Integer] Sheet name or index (default: first sheet)
      #   - :progress_callback [Proc] Callback for progress updates
      # @return [Array<TestScenario>] Array of test scenarios
      def import_excel(file_path, options = {})
        @errors = []
        @warnings = []

        options = {
          context_columns: nil,
          id_column: "id",
          expected_decision_column: "expected_decision",
          expected_confidence_column: "expected_confidence",
          skip_header: true,
          sheet: 0,
          progress_callback: nil
        }.merge(options)

        begin
          spreadsheet = Roo::Spreadsheet.open(file_path)
          
          # Select sheet by name or index
          if options[:sheet].is_a?(Integer)
            spreadsheet.default_sheet = spreadsheet.sheets[options[:sheet]] || spreadsheet.sheets.first
          elsif options[:sheet].is_a?(String)
            spreadsheet.default_sheet = options[:sheet]
          else
            spreadsheet.default_sheet = spreadsheet.sheets.first
          end

          scenarios = []
          row_number = 0

          # Get total rows for progress tracking
          total_rows = spreadsheet.last_row || 0
          total_rows -= 1 if options[:skip_header] && total_rows > 0

          # Read header row if skip_header is true
          header_row = nil
          if options[:skip_header] && spreadsheet.first_row
            header_row = spreadsheet.row(spreadsheet.first_row)
            row_number = 1 # Start from row 2 (after header)
          end

          # Process data rows
          start_row = options[:skip_header] ? (spreadsheet.first_row + 1) : spreadsheet.first_row
          (start_row..spreadsheet.last_row).each do |row_index|
            row_number += 1
            row_data = spreadsheet.row(row_index)

            begin
              # Convert row data to hash using headers
              row_hash = if header_row
                header_row.each_with_index.to_h { |header, idx| [header.to_s, row_data[idx]] }
              else
                # Use numeric indices if no headers
                row_data.each_with_index.to_h { |val, idx| [idx.to_s, val] }
              end

              scenario = parse_hash_row(row_hash, row_number, options)
              scenarios << scenario if scenario
            rescue StandardError => e
              @errors << "Row #{row_number}: #{e.message}"
            end

            # Call progress callback if provided
            if options[:progress_callback] && total_rows > 0
              processed = row_number - (options[:skip_header] ? 1 : 0)
              options[:progress_callback].call(
                processed: processed,
                total: total_rows,
                percentage: (processed.to_f / total_rows * 100).round(2)
              )
            end
          end

          raise ImportError, "Failed to import: #{@errors.join('; ')}" if @errors.any? && scenarios.empty?

          scenarios
        rescue Roo::HeaderRowNotFoundError => e
          raise ImportError, "Excel file has no header row: #{e.message}"
        rescue StandardError => e
          raise ImportError, "Failed to read Excel file: #{e.message}"
        end
      end

      # Import test scenarios from an array of hashes (for programmatic use)
      # @param data [Array<Hash>] Array of hashes with test data
      # @param options [Hash] Same as import_csv
      # @return [Array<TestScenario>] Array of test scenarios
      def import_from_array(data, options = {})
        @errors = []
        @warnings = []

        options = {
          id_column: "id",
          expected_decision_column: "expected_decision",
          expected_confidence_column: "expected_confidence"
        }.merge(options)

        scenarios = []
        row_number = 0

        data.each do |row|
          row_number += 1
          begin
            scenario = parse_hash_row(row, row_number, options)
            scenarios << scenario if scenario
          rescue StandardError => e
            @errors << "Row #{row_number}: #{e.message}"
          end
        end

        raise ImportError, "Failed to import: #{@errors.join('; ')}" if @errors.any? && scenarios.empty?

        scenarios
      end

      private

      def parse_csv_row(row, row_number, options)
        # Convert CSV::Row to hash
        row_hash = row.to_h

        # Extract ID
        id = extract_value(row_hash, options[:id_column], row_number, required: true)

        # Extract expected results (only if column names are provided)
        expected_decision = nil
        expected_confidence = nil

        if options[:expected_decision_column]
          expected_decision = extract_value(row_hash, options[:expected_decision_column], row_number, required: false)
        end

        if options[:expected_confidence_column]
          expected_confidence = extract_value(row_hash, options[:expected_confidence_column], row_number, required: false)
        end

        # Build context from remaining columns
        context_columns = options[:context_columns] || determine_context_columns(
          row_hash.keys,
          options[:id_column],
          options[:expected_decision_column],
          options[:expected_confidence_column]
        )

        context = {}
        context_columns.each do |col|
          next if col.nil?
          context[col.to_sym] = row_hash[col] if row_hash.key?(col)
        end

        # Validate context is not empty
        if context.empty?
          raise InvalidTestDataError.new("Context is empty", row_number: row_number)
        end

        # Parse expected_confidence as float if present
        expected_confidence = expected_confidence.to_f if expected_confidence && !expected_confidence.to_s.strip.empty?

        TestScenario.new(
          id: id,
          context: context,
          expected_decision: expected_decision,
          expected_confidence: expected_confidence,
          metadata: { row_number: row_number }
        )
      end

      def parse_hash_row(row, row_number, options)
        # Ensure row is a hash
        row_hash = row.is_a?(Hash) ? row : row.to_h

        # Extract ID
        id = extract_value(row_hash, options[:id_column], row_number, required: true)

        # Extract expected results
        expected_decision = extract_value(row_hash, options[:expected_decision_column], row_number, required: false)
        expected_confidence = extract_value(row_hash, options[:expected_confidence_column], row_number, required: false)

        # Build context from remaining keys
        context_keys = row_hash.keys.reject do |key|
          key_str = key.to_s
          [options[:id_column], options[:expected_decision_column], options[:expected_confidence_column]].include?(key_str)
        end

        context = {}
        context_keys.each do |key|
          context[key.is_a?(Symbol) ? key : key.to_sym] = row_hash[key]
        end

        # Validate context is not empty
        if context.empty?
          raise InvalidTestDataError.new("Context is empty", row_number: row_number)
        end

        # Parse expected_confidence as float if present
        expected_confidence = expected_confidence.to_f if expected_confidence && !expected_confidence.to_s.strip.empty?

        TestScenario.new(
          id: id,
          context: context,
          expected_decision: expected_decision,
          expected_confidence: expected_confidence,
          metadata: { row_number: row_number }
        )
      end

      def extract_value(row_hash, column_name, row_number, required: false)
        # Try both string and symbol keys
        value = row_hash[column_name] || row_hash[column_name.to_sym] || row_hash[column_name.to_s]

        if required && (value.nil? || value.to_s.strip.empty?)
          raise InvalidTestDataError.new("Missing required column: #{column_name}", row_number: row_number)
        end

        value
      end

      def determine_context_columns(all_columns, id_column, expected_decision_column, expected_confidence_column)
        excluded = [id_column, expected_decision_column, expected_confidence_column].map(&:to_s)
        all_columns.reject { |col| excluded.include?(col.to_s) }
      end

      def count_csv_rows(file_path, skip_header)
        count = 0
        CSV.foreach(file_path, headers: skip_header) do |_row|
          count += 1
        end
        count
      rescue StandardError
        # If we can't count, return nil (progress tracking will be disabled)
        nil
      end
    end
  end
end

