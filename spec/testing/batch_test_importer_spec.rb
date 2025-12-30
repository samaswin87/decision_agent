require "spec_helper"
require "tempfile"

RSpec.describe DecisionAgent::Testing::BatchTestImporter do
  let(:importer) { DecisionAgent::Testing::BatchTestImporter.new }

  describe "#import_csv" do
    context "with valid CSV file" do
      it "imports test scenarios from CSV" do
        csv_content = <<~CSV
          id,user_id,amount,expected_decision,expected_confidence
          test_1,123,1000,approve,0.95
          test_2,456,5000,reject,0.80
        CSV

        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.close

        scenarios = importer.import_csv(file.path)

        expect(scenarios.size).to eq(2)
        expect(scenarios[0].id).to eq("test_1")
        expect(scenarios[0].context[:user_id]).to eq("123")
        expect(scenarios[0].context[:amount]).to eq("1000")
        expect(scenarios[0].expected_decision).to eq("approve")
        expect(scenarios[0].expected_confidence).to eq(0.95)

        file.unlink
      end

      it "handles CSV without expected results" do
        csv_content = <<~CSV
          id,user_id,amount
          test_1,123,1000
          test_2,456,5000
        CSV

        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.close

        scenarios = importer.import_csv(file.path,
                                        expected_decision_column: "nonexistent_column",
                                        expected_confidence_column: "nonexistent_column")

        expect(scenarios.size).to eq(2)
        expect(scenarios[0].expected_result?).to be false

        file.unlink
      end

      it "handles custom column names" do
        csv_content = <<~CSV
          test_id,customer_id,transaction_amount,expected_outcome,expected_score
          test_1,123,1000,approve,0.95
        CSV

        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.close

        scenarios = importer.import_csv(file.path,
                                        id_column: "test_id",
                                        expected_decision_column: "expected_outcome",
                                        expected_confidence_column: "expected_score")

        expect(scenarios.size).to eq(1)
        expect(scenarios[0].id).to eq("test_1")
        expect(scenarios[0].context[:customer_id]).to eq("123")
        expect(scenarios[0].context[:transaction_amount]).to eq("1000")
        expect(scenarios[0].expected_decision).to eq("approve")
        expect(scenarios[0].expected_confidence).to eq(0.95)

        file.unlink
      end

      it "handles CSV without header row" do
        csv_content = <<~CSV
          test_1,123,1000
          test_2,456,5000
        CSV

        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.close

        scenarios = importer.import_csv(file.path, skip_header: false, id_column: "0")

        # Without headers, column names will be numeric
        expect(scenarios.size).to eq(2)

        file.unlink
      end

      it "handles CSV with context_columns option" do
        csv_content = <<~CSV
          id,user_id,amount,extra_field,expected_decision
          test_1,123,1000,extra_value,approve
        CSV

        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.close

        scenarios = importer.import_csv(file.path, context_columns: %w[user_id amount])

        expect(scenarios[0].context.keys).to match_array(%i[user_id amount])
        expect(scenarios[0].context[:extra_field]).to be_nil

        file.unlink
      end

      it "handles nil context column values" do
        csv_content = <<~CSV
          id,user_id,amount
          test_1,123,
        CSV

        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.close

        scenarios = importer.import_csv(file.path)
        expect(scenarios.size).to eq(1)
        expect(scenarios[0].context[:amount]).to be_nil

        file.unlink
      end
    end

    context "with invalid CSV file" do
      it "raises error when required id column is missing" do
        csv_content = <<~CSV
          user_id,amount
          123,1000
        CSV

        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.close

        expect do
          importer.import_csv(file.path)
        end.to raise_error(DecisionAgent::ImportError)

        file.unlink
      end

      it "collects errors for invalid rows" do
        csv_content = <<~CSV
          id,user_id,amount
          test_1,123,1000
          ,456,5000
          test_3,789,2000
        CSV

        file = Tempfile.new(["test", ".csv"])
        file.write(csv_content)
        file.close

        scenarios = importer.import_csv(file.path)

        # Should import valid rows and collect errors
        expect(scenarios.size).to eq(2)
        expect(importer.errors).not_to be_empty

        file.unlink
      end
    end
  end

  describe "#import_from_array" do
    it "imports test scenarios from array of hashes" do
      data = [
        {
          id: "test_1",
          user_id: 123,
          amount: 1000,
          expected_decision: "approve",
          expected_confidence: 0.95
        },
        {
          id: "test_2",
          user_id: 456,
          amount: 5000,
          expected_decision: "reject"
        }
      ]

      scenarios = importer.import_from_array(data)

      expect(scenarios.size).to eq(2)
      expect(scenarios[0].id).to eq("test_1")
      expect(scenarios[0].context[:user_id]).to eq(123)
      expect(scenarios[0].context[:amount]).to eq(1000)
      expect(scenarios[0].expected_decision).to eq("approve")
      expect(scenarios[0].expected_confidence).to eq(0.95)
    end

    it "handles string keys in hash" do
      data = [
        {
          "id" => "test_1",
          "user_id" => 123,
          "amount" => 1000
        }
      ]

      scenarios = importer.import_from_array(data)

      expect(scenarios.size).to eq(1)
      expect(scenarios[0].context[:user_id]).to eq(123)
    end

    it "raises ImportError when context is empty and all rows fail" do
      data = [
        {
          id: "test_1",
          expected_decision: "approve"
        }
      ]

      expect do
        importer.import_from_array(data)
      end.to raise_error(DecisionAgent::ImportError, /Failed to import/)
    end

    it "does not support context_columns option (ignores it)" do
      data = [
        {
          id: "test_1",
          user_id: 123,
          amount: 1000,
          extra_field: "not_ignored",
          expected_decision: "approve"
        }
      ]

      scenarios = importer.import_from_array(data, context_columns: %w[user_id amount])
      # parse_hash_row doesn't use context_columns, so extra_field should still be included
      expect(scenarios[0].context.keys).to include(:user_id, :amount, :extra_field)
    end
  end

  describe "progress callback" do
    it "calls progress callback during CSV import" do
      csv_content = <<~CSV
        id,user_id,amount
        test_1,123,1000
        test_2,456,5000
        test_3,789,2000
      CSV

      file = Tempfile.new(["test", ".csv"])
      file.write(csv_content)
      file.close

      progress_calls = []
      importer.import_csv(file.path, progress_callback: lambda { |progress|
        progress_calls << progress
      })

      expect(progress_calls.size).to eq(3)
      expect(progress_calls.last[:processed]).to eq(3)
      expect(progress_calls.last[:total]).to eq(3)
      expect(progress_calls.last[:percentage]).to be_between(0, 100)

      file.unlink
    end
  end

  describe "#import_excel" do
    context "when Roo is available" do
      before do
        skip "Roo gem not available" unless defined?(Roo)
      end

      it "raises error for invalid Excel file" do
        file = Tempfile.new(["test", ".xlsx"])
        file.write("not excel content")
        file.close

        expect do
          importer.import_excel(file.path)
        end.to raise_error(DecisionAgent::ImportError)

        file.unlink
      end

      it "handles HeaderRowNotFoundError" do
        # Mock Roo to raise HeaderRowNotFoundError
        spreadsheet_double = double("Spreadsheet")
        allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet_double)
        allow(spreadsheet_double).to receive(:sheets).and_return(["Sheet1"])
        allow(spreadsheet_double).to receive(:default_sheet=)
        allow(spreadsheet_double).to receive(:first_row).and_return(nil)
        allow(spreadsheet_double).to receive(:last_row).and_raise(Roo::HeaderRowNotFoundError)

        file = Tempfile.new(["test", ".xlsx"])
        file.write("content")
        file.close

        expect do
          importer.import_excel(file.path)
        end.to raise_error(DecisionAgent::ImportError, /no header row/)

        file.unlink
      end
    end
  end

  describe "error handling" do
    it "raises ImportError when all rows fail" do
      csv_content = <<~CSV
        user_id,amount
        123,1000
      CSV

      file = Tempfile.new(["test", ".csv"])
      file.write(csv_content)
      file.close

      expect do
        importer.import_csv(file.path)
      end.to raise_error(DecisionAgent::ImportError)

      file.unlink
    end

    it "collects warnings" do
      expect(importer.warnings).to eq([])
    end

    it "handles empty CSV file" do
      file = Tempfile.new(["test", ".csv"])
      file.write("id,user_id\n")
      file.close

      scenarios = importer.import_csv(file.path)
      expect(scenarios).to be_empty

      file.unlink
    end
  end

  describe "edge cases" do
    it "handles numeric confidence values" do
      data = [
        {
          id: "test_1",
          user_id: 123,
          expected_confidence: "0.95"
        }
      ]

      scenarios = importer.import_from_array(data)
      expect(scenarios[0].expected_confidence).to eq(0.95)
    end

    it "handles empty confidence string" do
      data = [
        {
          id: "test_1",
          user_id: 123,
          expected_confidence: ""
        }
      ]

      scenarios = importer.import_from_array(data)
      # Empty string gets converted to 0.0 by to_f when not stripped empty
      # The code checks !expected_confidence.to_s.strip.empty? before conversion
      expect(scenarios[0].expected_confidence).to eq(0.0)
    end

    it "handles symbol keys in context" do
      data = [
        {
          id: "test_1",
          user_id: 123
        }
      ]

      scenarios = importer.import_from_array(data)
      expect(scenarios[0].context[:user_id]).to eq(123)
    end

    it "handles numeric confidence in string format" do
      data = [
        {
          id: "test_1",
          user_id: 123,
          expected_confidence: "0.95"
        }
      ]

      scenarios = importer.import_from_array(data)
      expect(scenarios[0].expected_confidence).to eq(0.95)
    end

    it "handles whitespace in confidence string" do
      data = [
        {
          id: "test_1",
          user_id: 123,
          expected_confidence: "  0.95  "
        }
      ]

      scenarios = importer.import_from_array(data)
      expect(scenarios[0].expected_confidence).to eq(0.95)
    end
  end

  describe "private methods edge cases" do
    it "handles count_csv_rows errors gracefully" do
      csv_content = <<~CSV
        id,user_id
        test_1,123
      CSV

      file = Tempfile.new(["test", ".csv"])
      file.write(csv_content)
      file.close

      # Stub count_csv_rows to raise an error, but allow import_csv to work normally
      allow(importer).to receive(:count_csv_rows).and_raise(StandardError.new("File error"))

      # Should still work but without progress tracking (total_rows will be nil)
      scenarios = importer.import_csv(file.path, progress_callback: ->(_) {})

      expect(scenarios.size).to eq(1)

      file.unlink
    end
  end

  describe "#import_excel comprehensive tests" do
    context "when Roo is available" do
      before do
        skip "Roo gem not available" unless defined?(Roo)
      end

      let(:spreadsheet_double) do
        double("Spreadsheet",
               sheets: %w[Sheet1 Sheet2],
               first_row: 1,
               last_row: 3)
      end

      before do
        allow(spreadsheet_double).to receive(:default_sheet=)
        allow(spreadsheet_double).to receive(:row) do |idx|
          case idx
          when 1
            %w[id user_id amount]
          when 2
            %w[test_1 123 1000]
          when 3
            %w[test_2 456 5000]
          end
        end
      end

      it "imports Excel file with default sheet" do
        allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet_double)

        scenarios = importer.import_excel("test.xlsx")

        expect(scenarios.size).to eq(2)
        expect(scenarios[0].id).to eq("test_1")
      end

      it "imports Excel file with sheet index" do
        allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet_double)
        allow(spreadsheet_double).to receive(:sheets).and_return(%w[Sheet1 Sheet2])

        scenarios = importer.import_excel("test.xlsx", sheet: 1)

        expect(scenarios.size).to eq(2)
      end

      it "imports Excel file with sheet name" do
        allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet_double)

        scenarios = importer.import_excel("test.xlsx", sheet: "Sheet2")

        expect(scenarios.size).to eq(2)
      end

      it "imports Excel file without header" do
        allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet_double)
        allow(spreadsheet_double).to receive(:first_row).and_return(1)
        allow(spreadsheet_double).to receive(:last_row).and_return(2)
        allow(spreadsheet_double).to receive(:row) do |idx|
          case idx
          when 1
            %w[test_1 123 1000]
          when 2
            %w[test_2 456 5000]
          end
        end

        scenarios = importer.import_excel("test.xlsx", skip_header: false, id_column: "0")

        expect(scenarios.size).to eq(2)
      end

      it "calls progress callback during Excel import" do
        allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet_double)

        progress_calls = []
        importer.import_excel("test.xlsx", progress_callback: lambda { |progress|
          progress_calls << progress
        })

        expect(progress_calls.size).to eq(2)
        expect(progress_calls.last[:processed]).to eq(2)
      end

      it "handles Excel file with no rows" do
        empty_spreadsheet = double("Spreadsheet",
                                   sheets: ["Sheet1"],
                                   first_row: 1,
                                   last_row: 1,
                                   row: %w[id user_id amount])
        allow(empty_spreadsheet).to receive(:default_sheet=)

        allow(Roo::Spreadsheet).to receive(:open).and_return(empty_spreadsheet)

        scenarios = importer.import_excel("test.xlsx")
        expect(scenarios).to be_empty
      end

      it "handles Excel import with custom column names" do
        allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet_double)

        scenarios = importer.import_excel("test.xlsx",
                                          id_column: "id",
                                          expected_decision_column: "expected_decision",
                                          expected_confidence_column: "expected_confidence")

        expect(scenarios.size).to eq(2)
      end

      it "handles StandardError during Excel import" do
        allow(Roo::Spreadsheet).to receive(:open).and_raise(StandardError.new("File corrupted"))

        expect do
          importer.import_excel("test.xlsx")
        end.to raise_error(DecisionAgent::ImportError, /Failed to read Excel file/)
      end
    end
  end

  describe "CSV import edge cases" do
    it "handles CSV import without progress callback" do
      csv_content = <<~CSV
        id,user_id,amount
        test_1,123,1000
      CSV

      file = Tempfile.new(["test", ".csv"])
      file.write(csv_content)
      file.close

      scenarios = importer.import_csv(file.path, progress_callback: nil)
      expect(scenarios.size).to eq(1)

      file.unlink
    end

    it "handles CSV with progress callback but count_csv_rows fails" do
      csv_content = <<~CSV
        id,user_id,amount
        test_1,123,1000
        test_2,456,5000
      CSV

      file = Tempfile.new(["test", ".csv"])
      file.write(csv_content)
      file.close

      # Stub count_csv_rows to return nil (simulating error)
      allow(importer).to receive(:count_csv_rows).and_return(nil)

      progress_calls = []
      scenarios = importer.import_csv(file.path, progress_callback: lambda { |progress|
        progress_calls << progress
      })

      expect(scenarios.size).to eq(2)
      # Progress callback should not be called when total_rows is nil
      expect(progress_calls).to be_empty

      file.unlink
    end

    it "handles CSV row parsing that returns nil scenario" do
      csv_content = <<~CSV
        id,user_id,amount
        test_1,123,1000
      CSV

      file = Tempfile.new(["test", ".csv"])
      file.write(csv_content)
      file.close

      # Stub parse_csv_row to return nil
      allow(importer).to receive(:parse_csv_row).and_return(nil)

      scenarios = importer.import_csv(file.path)
      expect(scenarios).to be_empty

      file.unlink
    end

    it "handles extract_value with symbol keys" do
      data = [
        {
          id: "test_1",
          user_id: 123
        }
      ]

      scenarios = importer.import_from_array(data)
      expect(scenarios[0].context[:user_id]).to eq(123)
    end

    it "handles extract_value with string keys" do
      data = [
        {
          "id" => "test_1",
          "user_id" => 123
        }
      ]

      scenarios = importer.import_from_array(data)
      expect(scenarios[0].id).to eq("test_1")
      expect(scenarios[0].context[:user_id]).to eq(123)
    end

    it "handles CSV with nil column values in context" do
      csv_content = <<~CSV
        id,user_id,amount,description
        test_1,123,1000,
      CSV

      file = Tempfile.new(["test", ".csv"])
      file.write(csv_content)
      file.close

      scenarios = importer.import_csv(file.path)
      expect(scenarios[0].context[:description]).to be_nil

      file.unlink
    end

    it "handles CSV with numeric keys when no headers" do
      csv_content = <<~CSV
        test_1,123,1000
        test_2,456,5000
      CSV

      file = Tempfile.new(["test", ".csv"])
      file.write(csv_content)
      file.close

      scenarios = importer.import_csv(file.path, skip_header: false, id_column: "0")
      expect(scenarios.size).to eq(2)
      expect(scenarios[0].id).to eq("test_1")

      file.unlink
    end

    it "handles CSV context_columns with nil values" do
      csv_content = <<~CSV
        id,user_id,amount,extra
        test_1,123,1000,value
      CSV

      file = Tempfile.new(["test", ".csv"])
      file.write(csv_content)
      file.close

      scenarios = importer.import_csv(file.path, context_columns: ["user_id", nil, "amount"])
      expect(scenarios[0].context.keys).to include(:user_id, :amount)
      expect(scenarios[0].context.keys).not_to include(nil)

      file.unlink
    end
  end
end
