# Simulation and What-If Analysis module
# Provides tools for scenario testing, historical replay, impact analysis, shadow testing, and Monte Carlo simulation

require_relative "simulation/errors"
require_relative "simulation/replay_engine"
require_relative "simulation/what_if_analyzer"
require_relative "simulation/impact_analyzer"
require_relative "simulation/shadow_test_engine"
require_relative "simulation/scenario_engine"
require_relative "simulation/scenario_library"
require_relative "simulation/monte_carlo_simulator"

module DecisionAgent
  module Simulation
    # Main entry point for simulation features
  end
end
