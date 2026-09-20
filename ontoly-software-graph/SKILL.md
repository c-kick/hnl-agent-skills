---
name: ontoly-software-graph
description: Build and query Ontoly's deterministic Software Graph before manually searching a TypeScript repository. Use when asked about architecture, dependencies, routes, services, modules, request traces, impact analysis, configuration, or codebase onboarding.
---

# Ontoly Software Graph

Use this skill when a user asks codebase-understanding questions that should be answered from Ontoly's graph evidence before manual file search.

## Workflow

1. Check whether the repository already has an Ontoly graph.
2. If the graph is missing or stale, build it:

```bash
ontoly build .
```

3. Review graph diagnostics, trust, graph hash, and framework detection.
4. Query Ontoly through the CLI or MCP before inspecting source files directly.
5. Cite graph evidence in answers: node IDs, edge types, route paths, package names, source locations, diagnostics, and confidence.
6. Only fall back to file search when Ontoly cannot answer, reports low confidence, or the user explicitly asks for source-level review.

## Useful Commands

```bash
ontoly build .
ontoly inspect
ontoly graph
ontoly trace
ontoly mcp
```

## Guardrails

- Do not invent architecture relationships that are not present in the graph.
- Separate measured graph facts from inferred observations.
- If evidence is missing, explain which Ontoly query or validation step should run next.
