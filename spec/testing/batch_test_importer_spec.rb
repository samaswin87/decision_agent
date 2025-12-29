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
        expect(scenarios[0].has_expected_result?).to be false

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
  end
end

