# decision_agent

A deterministic, explainable, and auditable decision-making engine for Ruby.

`decision_agent` helps you answer questions like:
- *Should this action happen?*
- *Why did it happen?*
- *How confident was the system?*
- *Can we replay and verify this decision later?*

It is designed for **enterprise**, **healthcare**, and **long-lived systems** where correctness, explainability, and auditability matter more than “AI magic”.

---

## Why decision_agent?

`decision_agent` combines the best ideas while fixing these gaps.

---

## Core Principles

- **Deterministic by default**  
  Same input → same output

- **Explainable**  
  Every decision includes human-readable reasons

- **Auditable & replayable**  
  Decisions can be reproduced exactly later

- **Composable**  
  Rules, evaluators, scoring strategies are pluggable

- **Framework-agnostic**  
  No Rails, no ActiveRecord, no background jobs

- **AI-optional**  
  AI can assist — never replace — rules

---

## Installation

```bash
bundle add decision_agent
