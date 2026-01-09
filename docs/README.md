# DecisionAgent Documentation

Welcome to the DecisionAgent documentation.

## 📚 Documentation Tree

### Getting Started
- [Main README](../README.md) - Installation, quick start, and overview
- [Code Examples](CODE_EXAMPLES.md) - Comprehensive code snippets and usage patterns
- [Examples](../examples/README.md) - Working examples with explanations
- [Development Setup](DEVELOPMENT_SETUP.md) - Development environment setup and testing

### Core Features
- [**Explainability Layer**](EXPLAINABILITY.md) - Machine-readable decision explanations with condition-level tracing
- [**Data Enrichment**](DATA_ENRICHMENT.md) - REST API data enrichment with caching and circuit breaker
- [**DMN Guide**](DMN_GUIDE.md) - Complete DMN 1.3 support guide
- [**DMN API Reference**](DMN_API.md) - DMN API documentation
- [**FEEL Reference**](FEEL_REFERENCE.md) - FEEL expression language reference
- [**DMN Migration Guide**](DMN_MIGRATION_GUIDE.md) - Migrating from JSON to DMN
- [**DMN Best Practices**](DMN_BEST_PRACTICES.md) - DMN modeling best practices
- [**Versioning System**](VERSIONING.md) - Rule version control, rollback, and history
- [**Simulation and What-If Analysis**](SIMULATION.md) - Historical replay, what-if analysis, impact analysis, and shadow testing
- [**A/B Testing**](AB_TESTING.md) - Compare rule versions with statistical analysis
- [**Batch Testing**](BATCH_TESTING.md) - Test rules against large datasets with CSV/Excel import
- [**RBAC Configuration**](RBAC_CONFIGURATION.md) - Role-based access control setup and integration
- [**RBAC Quick Reference**](RBAC_QUICK_REFERENCE.md) - Quick reference for RBAC configuration
- [**Web UI**](WEB_UI.md) - Visual rule builder interface
- [**Web UI Setup**](WEB_UI_SETUP.md) - Setup and configuration guide
- [**Web UI Rails Integration**](WEB_UI_RAILS_INTEGRATION.md) - Mount in Rails/Rack apps

### Monitoring & Analytics
- [**Monitoring & Analytics**](MONITORING_AND_ANALYTICS.md) - Real-time monitoring, metrics, and alerting
- [**Monitoring Architecture**](MONITORING_ARCHITECTURE.md) - System architecture and design
- [**Persistent Monitoring**](PERSISTENT_MONITORING.md) - Database storage for long-term analytics

### Performance & Thread-Safety
- [**Performance & Thread-Safety Summary**](PERFORMANCE_AND_THREAD_SAFETY.md) - Executive summary, benchmarks, and production readiness
- [**Thread-Safety Implementation**](THREAD_SAFETY.md) - Detailed implementation guide and migration notes
- [**Benchmarks**](../benchmarks/README.md) - Comprehensive benchmark suite, performance testing, and regression tracking

### Reference
- [**API Contract**](API_CONTRACT.md) - Complete API specifications
- [**Changelog**](CHANGELOG.md) - Version history and updates

## 📝 Documentation Structure

```
docs/
├── README.md (this file) - Documentation index and navigation
│
├── Getting Started
│   ├── CODE_EXAMPLES.md          - Code snippets and usage patterns
│   ├── DEVELOPMENT_SETUP.md      - Development environment setup
│   └── See ../README.md and ../examples/README.md
│
├── Core Features
│   ├── DATA_ENRICHMENT.md          - REST API data enrichment guide
│   ├── DMN_GUIDE.md                - Complete DMN 1.3 support guide
│   ├── DMN_API.md                 - DMN API documentation
│   ├── FEEL_REFERENCE.md          - FEEL expression language reference
│   ├── DMN_MIGRATION_GUIDE.md     - Migrating from JSON to DMN
│   ├── DMN_BEST_PRACTICES.md      - DMN modeling best practices
│   ├── VERSIONING.md               - Rule version control and management
│   ├── SIMULATION.md               - Simulation, what-if analysis, and shadow testing
│   ├── AB_TESTING.md               - A/B testing with statistical analysis
│   ├── BATCH_TESTING.md            - Batch testing guide with CSV/Excel import
│   ├── RBAC_CONFIGURATION.md       - Role-based access control setup
│   ├── RBAC_QUICK_REFERENCE.md     - Quick RBAC reference
│   ├── WEB_UI.md                   - Web interface user guide
│   ├── WEB_UI_SETUP.md             - Web interface setup
│   └── WEB_UI_RAILS_INTEGRATION.md - Mount in Rails/Rack apps
│
├── Monitoring & Analytics
│   ├── MONITORING_AND_ANALYTICS.md - Real-time monitoring, metrics, and alerting
│   ├── MONITORING_ARCHITECTURE.md  - System architecture and design
│   └── PERSISTENT_MONITORING.md    - Database storage for long-term analytics
│
├── Performance & Thread-Safety
│   ├── PERFORMANCE_AND_THREAD_SAFETY.md  - Executive summary and benchmarks
│   ├── THREAD_SAFETY.md                  - Implementation details
│   └── ../benchmarks/README.md           - Benchmark suite and performance testing
│
└── Reference
    ├── API_CONTRACT.md             - Full API reference
    └── CHANGELOG.md                - Release notes and history
```

## 🔗 Quick Links

- [Installation](../README.md#installation)
- [Quick Start](../README.md#quick-start)
- [Examples Directory](../examples/)
- [GitHub Issues](https://github.com/samaswin/decision_agent/issues)

## 📖 Additional Resources

For detailed guides on specific topics, see the main [README](../README.md#documentation) tree structure.

## Contributing

To contribute to the documentation:

1. Fork the repository
2. Edit or add markdown files in the `docs/` directory
3. Update this index if adding new files
4. Submit a pull request

---

**Note**: The tree structure in the main README shows the complete documentation map. Some advanced guides may be extracted into separate files as the project grows.
