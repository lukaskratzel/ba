# Introduction Diagram Tasks

## Goal

Collect diagrams that are useful for the introduction and early thesis chapters, but
are intentionally deferred for now.

## Tasks

- Create a refreshed system context diagram that shows Artemis, the landing page,
  Theia Cloud service, Theia Cloud operator, Kubernetes, Gateway API / Envoy
  Gateway, Scorpio, and the personalized Theia session. Reuse the proposal figure
  only as a starting point; the final diagram should reflect the implemented
  architecture.
- Create a startup-scope diagram that marks the evaluation boundary used in the
  thesis: from the landing page request until the session URL is ready. Explicitly
  exclude browser-side IDE loading after the URL is opened.
- Create an activity diagram for the two main startup paths: eager session
  assignment from the prewarmed pool and lazy fallback when no warm capacity is
  available.
- Create a focused personalization diagram that shows when user-specific data is
  injected into an already running session and how Scorpio accesses that runtime
  data in the Theia environment.
- Revisit whether one overview diagram can be reused across Introduction,
  Requirements, and System Design to avoid maintaining multiple partially redundant
  figures.
