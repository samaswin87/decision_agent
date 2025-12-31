# DecisionAgent Documentation

Welcome to the DecisionAgent documentation.

## 📚 Documentation Tree

### Getting Started
- [Main README](../README.md) - Installation, quick start, and overview
- [Code Examples](CODE_EXAMPLES.md) - Comprehensive code snippets and usage patterns
- [Examples](../examples/README.md) - Working examples with explanations

### Core Features
- [**Versioning System**](VERSIONING.md) - Rule version control, rollback, and history
- [**Web UI**](WEB_UI.md) - Visual rule builder interface
- [**Web UI Setup**](WEB_UI_SETUP.md) - Setup and configuration guide
- [**Web UI Rails Integration**](WEB_UI_RAILS_INTEGRATION.md) - Mount in Rails/Rack apps
- [**Batch Testing**](BATCH_TESTING.md) - Test rules against large datasets with CSV/Excel import

### Monitoring & Analytics
- [**Monitoring & Analytics**](MONITORING_AND_ANALYTICS.md) - Real-time monitoring, metrics, and alerting
- [**Monitoring Architecture**](MONITORING_ARCHITECTURE.md) - System architecture and design

### Performance & Thread-Safety
- [**Performance & Thread-Safety Summary**](PERFORMANCE_AND_THREAD_SAFETY.md) - Executive summary, benchmarks, and production readiness
- [**Thread-Safety Implementation**](THREAD_SAFETY.md) - Detailed implementation guide and migration notes

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
│   └── See ../README.md and ../examples/README.md
│
├── Core Features
│   ├── VERSIONING.md               - Rule version control and management
│   ├── WEB_UI.md                   - Web interface user guide
│   ├── WEB_UI_SETUP.md             - Web interface setup
│   ├── WEB_UI_RAILS_INTEGRATION.md - Mount in Rails/Rack apps
│   └── BATCH_TESTING.md            - Batch testing guide with CSV/Excel import
│
├── Monitoring & Analytics
│   ├── MONITORING_AND_ANALYTICS.md - Real-time monitoring, metrics, and alerting
│   └── MONITORING_ARCHITECTURE.md  - System architecture and design
│
├── Performance & Thread-Safety
│   ├── PERFORMANCE_AND_THREAD_SAFETY.md  - Executive summary and benchmarks
│   └── THREAD_SAFETY.md                  - Implementation details
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
