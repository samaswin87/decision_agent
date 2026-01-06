module DecisionAgent
  module Simulation
    # Base error class for simulation module
    class SimulationError < StandardError; end

    # Error raised when scenario execution fails
    class ScenarioExecutionError < SimulationError; end

    # Error raised when historical data is invalid
    class InvalidHistoricalDataError < SimulationError; end

    # Error raised when version comparison fails
    class VersionComparisonError < SimulationError; end

    # Error raised when shadow test configuration is invalid
    class InvalidShadowTestError < SimulationError; end
  end
end
