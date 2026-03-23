# Implementation Overview for the Bachelor's Thesis

## Purpose of this Document

This document provides a high-level but technically grounded overview of the work implemented during the thesis project. It is intended as a compact technical foundation for the final thesis:

- it summarizes the actual system changes that were implemented,
- it explains how the individual components fit together,
- it highlights the main architectural decisions and their motivation,
- and it can serve as a starting point for later thesis chapters and diagrams.

The implemented work centers less on predictive scaling itself and more on the architectural prerequisites that make low-latency and later predictive scaling possible in practice:

- reliable eager session startup in Theia Cloud,
- runtime personalization of prewarmed sessions,
- faster routing propagation through Gateway API and Envoy Gateway,
- adaptation of the Artemis integration layer to the Theia environment,
- and a scaling API that exposes the relevant scaling parameters for future automation.

## Scope of the Implemented Work

The thesis work converged on the following concrete contributions:

- making eager session start in Theia Cloud robust enough for production-like use,
- enabling runtime injection of user-specific data into already running IDE containers,
- integrating that personalization flow with Scorpio and Artemis,
- improving request routing behavior by moving from ingress-nginx to Gateway API with Envoy Gateway,
- and exposing scaling parameters via an admin API so external scaling logic can adjust prewarming behavior.

This is best described as an architectural and systems implementation that prepares the platform for predictive scaling rather than a finished ML-based prediction system.

## Overall Narrative of the Work

The central problem was startup latency in cloud IDE sessions for educational use cases. A purely lazy startup approach creates pods only when a student requests a session, which leads to noticeable delays. Prewarming can reduce this delay, but prewarmed sessions are generic by default and therefore difficult to personalize securely at runtime.

The implemented solution addresses this end to end:

- Theia Cloud maintains a pool of prewarmed IDE instances for a given `AppDefinition`.
- When a user requests a session, the operator tries to reserve one of these already running instances.
- Session-specific metadata and routing are attached dynamically.
- User-specific runtime data such as credentials is injected after startup through a dedicated bridge component inside the IDE container.
- Scorpio was adapted so it can consume this runtime-injected data instead of assuming a classic VS Code desktop-style environment.
- Routing was migrated to Gateway API with Envoy Gateway, reducing the delay until a newly assigned session becomes reachable.
- A scaling API was introduced to allow external control of `minInstances` and `maxInstances`, which is the essential control surface for later predictive scaling.
- Concurrency-oriented control-plane measures were added so the system behaves well when many sessions start at once, such as at the beginning of an exam.

In short, the project turned prewarming from a static infrastructure idea into an actually usable personalized session-start pipeline.

An important semantic distinction in the final system is that `minInstances` and `maxInstances` control different things:

- `minInstances` controls the size of the prewarmed eager-start pool,
- `maxInstances` controls the total number of sessions that may exist for an app definition,
- and any demand beyond the prewarmed capacity defined by `minInstances` is handled through lazy startup as long as the total `maxInstances` limit is not exceeded.

## Main Contribution 1: Eager Session Start in Theia Cloud

### Goal

The main goal of the eager session start work was to reduce session startup time by reusing already running Theia instances instead of provisioning everything on demand.

### Architectural Idea

Instead of creating a fresh deployment, service, and route for every session request, the system prepares a pool of generic instances in advance. When a new session is requested, one of these instances is reserved and turned into the user's session.

This required more than just prestarting pods. The implementation also had to solve:

- ownership and lifecycle management of shared Kubernetes resources,
- safe reservation and release of prewarmed instances,
- dynamic route assignment,
- runtime personalization,
- cleanup and reset so instances can return to the pool.

### Key Components

The most important component diagram around eager session start should include at least the following elements:

- `EagerStartAppDefinitionAddedHandler`
- `PrewarmedResourcePool`
- `K8sResourceFactory`
- `EagerSessionHandler`
- `EagerWithLazyFallbackSessionHandler`
- `IngressManager`
- `SessionEnvCollector`
- `AsyncDataInjector`
- `DefaultDataBridgeClient`
- shared `HTTPRoute` resources in Kubernetes
- prewarmed Theia deployments and their external/internal services
- the `theia-data-bridge` extension running inside the IDE container

### AppDefinition-Level Pool Management

At the `AppDefinition` level, `EagerStartAppDefinitionAddedHandler` is responsible for maintaining the prewarmed pool.

Its job is to:

- verify that the required shared `HTTPRoute` exists,
- ensure the minimum number of prewarmed instances exists when an app definition is created,
- reconcile the pool when `minInstances` changes,
- and release pool resources when the app definition is deleted.

The actual resource management logic is delegated to `PrewarmedResourcePool`.

This means `minInstances` is the direct control parameter for eager startup capacity. It does not define the total number of sessions the system may run, only how many of them can be served immediately from the warm pool.

### PrewarmedResourcePool

`PrewarmedResourcePool` is the core internal abstraction behind eager session start. It manages prewarmed instance lifecycles and acts as the stateful bridge between the abstract scaling settings of an app definition and the concrete Kubernetes resources used for fast session start.

Its responsibilities include:

- creating missing prewarmed services, deployments, and config maps,
- reconciling the pool to a target instance count,
- tracking resource generations so outdated pool resources can be recreated,
- reserving an available instance for a session,
- finishing session-specific setup after reservation,
- releasing the instance after session termination,
- and restoring the instance to a reusable clean state.

Conceptually, each prewarmed instance consists of:

- an external service,
- an internal service,
- a deployment,
- and optionally config maps for proxy and email configuration.

The separation between external and internal services is important because the system needs different networking roles:

- externally reachable traffic routing for the user-facing session,
- and internal cluster access for runtime operations such as bridge-based data injection.

### Resource Creation and Reconciliation

`K8sResourceFactory` centralizes creation of Kubernetes resources from templates. This avoids scattering resource creation logic throughout the operator and makes eager and lazy startup paths structurally consistent.

For eager instances, the factory creates:

- the external service,
- the internal service,
- the deployment,
- and optional config maps.

An important detail is that prewarmed resources are labeled with the current `AppDefinition` generation. This allows the pool reconciler to detect outdated resources after specification changes and recreate them if necessary. That gives the eager startup path a reconciliation model rather than a one-time provisioning model.

### Session Assignment Flow

When a new session is created, `EagerSessionHandler` attempts to handle it through the prewarmed pool.

The high-level flow is:

1. validate that the session and referenced app definition are in a usable state,
2. locate the shared `HTTPRoute`,
3. reserve a free prewarmed instance from `PrewarmedResourcePool`,
4. annotate the session with the chosen startup strategy and instance id,
5. complete session setup by attaching session labels and ownership,
6. collect runtime environment data,
7. trigger asynchronous data injection if the data bridge is enabled,
8. add a path-specific route rule to the shared `HTTPRoute`,
9. asynchronously publish the reachable session URL,
10. mark the session as handled.

This is the heart of the `EagerSessionStart` mechanism.

### Reservation Semantics

Reservation is not just “pick a pod”. The implementation reserves a pair of services that belong to the same prewarmed instance and ensures the deployment ownership is transferred consistently enough for later cleanup.

The pool logic explicitly handles:

- already reserved instances for idempotency,
- partial reservations caused by race conditions or failures,
- rollback when only part of a reservation succeeds,
- no-capacity situations,
- and deterministic selection of the next available instance.

This is important because the prewarming mechanism would be brittle if reservation could leave resources in a half-assigned state.

For burst workloads, this part is also central because reservation inside `PrewarmedResourcePool` is synchronized and includes recovery for partial reservations. That reduces the risk of duplicate assignment or pool corruption when many sessions compete for warm instances concurrently.

### Completing Session Setup

Once an instance is reserved, `completeSessionSetup` turns the generic prewarmed instance into a session-bound one by:

- attaching session labels to the services,
- adding session ownership to the deployment,
- configuring per-session email data when Keycloak integration is used,
- and refreshing pods where needed so updated configuration becomes active.

This is the step where a generic warm instance becomes the user's actual session resource from the platform perspective.

### Cleanup and Reuse

When the session ends, the instance is released back to the pool.

Cleanup includes:

- removing session ownership,
- clearing session-specific labels,
- clearing email configuration,
- deleting the current pod so a fresh pod is recreated from the deployment,
- and reconciling the instance against the current app definition generation and target pool size.

This reset behavior matters because prewarming only works sustainably if reused instances do not retain user-specific state.

### Fallback Behavior

`EagerWithLazyFallbackSessionHandler` adds an important operational safeguard. If no prewarmed capacity is available, the system falls back to the existing lazy startup path instead of failing the session request entirely.

This means eager start improves latency when capacity exists, but does not reduce correctness or availability under load. For the thesis, this is important because it frames eager startup as an optimization layer on top of the existing provisioning model rather than as a separate incompatible system.

This also clarifies the runtime meaning of the scaling parameters:

- sessions up to the prewarmed pool size configured through `minInstances` can use eager startup,
- sessions above that pool size are started lazily,
- and `maxInstances` remains the overall upper bound for how many sessions of that app definition may exist at all.

## Main Contribution 2: Migration from ingress-nginx to Gateway API with Envoy Gateway

### Motivation

Reducing container startup time alone is not sufficient if routing changes still take too long to propagate. Even after a prewarmed instance is reserved, the student still has to wait until the route to that session becomes externally reachable.

This made routing propagation delay part of the end-to-end session startup problem.

### Implementation Direction

The routing layer was migrated from ingress-nginx to Kubernetes Gateway API with Envoy Gateway as the controller.

This had two major effects:

- it aligned the routing model more closely with how Theia Cloud dynamically exposes sessions,
- and it reduced the route update latency that contributes to overall session startup delay.

### IngressManager as the Routing Abstraction

`IngressManager` centralizes operations on shared `HTTPRoute` resources. Rather than creating a dedicated ingress per session, the operator updates a shared route by inserting or removing path-specific rules.

For each session path it creates:

- a redirect rule for the exact session path,
- and a backend routing rule for the path prefix.

The backend rule also rewrites the path prefix and sets `X-Forwarded-Uri` using Envoy runtime syntax. This is an important implementation detail because the current solution explicitly depends on Envoy Gateway semantics for correct forwarding behavior.

For high-throughput workloads, `IngressManager` also includes retry logic for `409 Conflict` errors when multiple session starts update the same shared `HTTPRoute` concurrently. This is a key concurrency measure because the route object is a shared hotspot during bursty session creation.

### Why This Matters for the Thesis

This migration is not just an infrastructure cleanup. It directly supports the performance goal of the thesis:

- eager session start reduces compute-side waiting time,
- Gateway API plus Envoy Gateway reduces networking-side waiting time.

Together, both changes contribute to lower perceived session startup latency.

It is therefore useful to present this routing migration in the thesis as an enabling optimization that complements eager start rather than as an unrelated deployment detail.

## Main Contribution 3: Concurrency Measures for Burst Session Starts

### Motivation

Educational cloud IDE workloads are bursty. A particularly important case is an exam start, where many users request sessions almost simultaneously.

In these scenarios, average startup latency is only one part of the problem. The control plane must also remain correct and efficient under heavy contention on shared resources.

### Main Concurrency Challenges

The implementation had to address several shared bottlenecks:

- multiple handler executions touching the same session,
- many reservations competing for the same prewarmed pool,
- many route updates targeting the same shared `HTTPRoute`,
- and personalization work that could otherwise lengthen the critical session-start path.

### Implemented Measures

The resulting design includes several explicit concurrency-oriented mechanisms:

- race-aware session state transitions via `SessionStatusUtil`,
- synchronized reservation in `PrewarmedResourcePool`,
- partial-reservation recovery and rollback,
- retry with backoff and jitter for `HTTPRoute` edit conflicts in `IngressManager`,
- asynchronous runtime data injection through `AsyncDataInjector`,
- and graceful fallback to lazy startup if warm capacity is exhausted.

### Session-Level Race Handling

`SessionStatusUtil` introduces a clear session-handling state machine with states such as `HANDLING`, `HANDLED`, and `ERROR`. Before the operator proceeds, it checks whether the session:

- was already completed,
- is currently in handling,
- or already failed previously.

This makes the handling path more idempotent and avoids duplicate work during highly concurrent event processing.

`EagerSessionHandler` also treats failures while marking a session as `HANDLING` as a possible race and re-evaluates the latest session state instead of assuming exclusive ownership.

### Pool Reservation Under Contention

The pool reservation path is synchronized, which is essential because the prewarmed pool is shared by all concurrent session requests for the same app definition.

The implementation also explicitly handles partial failures. If only one part of a reservation succeeds, the system either completes the matching counterpart reservation or rolls the state back. This prevents pool degradation under load.

### Shared Route Mutation Under Contention

The shared `HTTPRoute` is another central contention point during exam-like bursts because many new sessions must become reachable at nearly the same time.

To handle this, `IngressManager` retries route edits on `409 Conflict` with bounded retries and jittered backoff. This improves robustness under concurrent updates and reduces avoidable failures caused by optimistic-write conflicts.

### Shortening the Critical Path

Runtime personalization is required, but it does not have to block all operator progress. The implementation therefore schedules environment injection asynchronously. The operator can continue after scheduling the work, while `AsyncDataInjector` waits for the in-container bridge to become ready and performs the injection separately.

This reduces pressure on the hottest synchronous control-plane path during high-throughput periods.

### Graceful Degradation

If burst demand temporarily exceeds available prewarmed capacity, `EagerWithLazyFallbackSessionHandler` falls back to lazy session startup instead of failing the request.

This is an important part of the story for the thesis: the system was engineered not just for low latency in the ideal case, but also for correctness and availability under overload.

## Main Contribution 4: theia-data-bridge for Runtime Personalization

### Problem

Prewarmed sessions must be generic before assignment. If credentials or user-specific data were baked into the container at prewarm time, the whole approach would be unusable and unsafe.

Therefore the project needed a mechanism to personalize a running Theia session after reservation.

### High-Level Idea

`theia-data-bridge` is a VS Code/Theia extension that exposes a lightweight HTTP server inside the IDE container and stores injected data so other extensions can retrieve it through commands. 

This makes personalization a runtime concern instead of a provisioning-time concern.

### Internal Structure

The extension is intentionally small and focused:

- activation is gated by `DATA_BRIDGE_ENABLED`,
- it starts an HTTP server on `0.0.0.0`, default port `16281`,
- it exposes `POST /data` for injecting environment data,
- it exposes `GET /health` for readiness checks,
- it stores injected values in a `DataStorage` abstraction,
- it persists values via VS Code secret storage,
- and it exposes `dataBridge.getEnv` so other extensions can retrieve specific variables.

This architecture fits the existing microservice approach well because:

- the operator remains the orchestrator,
- the IDE container exposes only a minimal local API surface,
- and consumer extensions stay decoupled from Kubernetes details.

### End-to-End Injection Flow

The runtime personalization path spans multiple components:

1. `EagerSessionHandler` decides that runtime data injection is needed.
2. `SessionEnvCollector` gathers environment values from direct session env vars, config maps, and secrets.
3. `AsyncDataInjector` schedules asynchronous injection and polls the bridge health endpoint.
4. `DefaultDataBridgeClient` resolves the internal service IP and calls the bridge endpoint inside the IDE container.
5. `theia-data-bridge` stores the values and exposes them to other extensions via commands.

This is one of the most important parts of the thesis because it solves the main contradiction of prewarming:

- sessions should be generic before assignment,
- but personalized immediately after assignment.

## Main Contribution 5: Scorpio Adaptation for Theia and Runtime Credential Injection

### Role of Scorpio

Scorpio is the Artemis integration layer inside the IDE environment. It handles functionality such as:

- authentication,
- exercise discovery,
- repository cloning,
- submission,
- and synchronization of problem statements and feedback.

For the thesis architecture, Scorpio is the main consumer of the runtime-personalization mechanism provided by the data bridge.

### Problem in the Original Integration

A classic VS Code extension can often assume that relevant environment variables are already available in the process environment at activation time. That assumption breaks down for prewarmed Theia sessions because the container starts before the user-specific data exists.

This means the Theia environment requires a delayed, runtime-aware initialization strategy.

### Implemented Adaptation

The key change is the introduction of environment loading strategies in Scorpio:

- `ProcessEnvStrategy` for the legacy behavior,
- `DataBridgeStrategy` for prewarmed Theia sessions.

The selected strategy depends on `SCORPIO_THEIA_ENV_STRATEGY`. When set to `data-bridge`, Scorpio:

- activates the data bridge extension if needed,
- polls it for the required variables,
- waits until the complete environment is available,
- and only then continues with Theia-specific initialization.

This is a crucial adaptation because it synchronizes extension startup with asynchronous runtime personalization.

### Data Used by Scorpio

The environment model used by Scorpio contains, among others:

- `ARTEMIS_TOKEN`,
- `ARTEMIS_URL`,
- `GIT_URI`,
- `GIT_USER`,
- `GIT_MAIL`,
- and a `THEIA` marker.

These values are used to:

- silently create authentication sessions,
- configure the Artemis base URL,
- clone the right student repository into the Theia workspace,
- and configure git identity inside the IDE environment.

### Why This Matters

Without Scorpio changes, eager start plus data injection would still not yield a functioning student workflow. The platform would start a fast session, but the actual exercise tooling would still behave as if it were running in a normal desktop-oriented extension environment.

The Scorpio work therefore closes the gap between infrastructure optimization and actual educational usability.

## Main Contribution 6: Scaling API

### Goal

The scaling API exposes the scaling-relevant parameters of app definitions through a service API so they can be inspected and adjusted programmatically.

In the implemented system, the two key parameters have distinct semantics:

- `minInstances` defines the number of prewarmed instances maintained in the eager-start pool,
- `maxInstances` defines the total number of sessions allowed for that app definition,
- so the interval between `minInstances` and `maxInstances` represents the capacity that can still be served, but only through lazy startup.

### Implemented Functionality

The API currently supports:

- listing scaling settings for all app definitions,
- reading scaling settings for one app definition,
- patching `minInstances`,
- patching `maxInstances`.

The implementation is centered around `AppDefinitionAdminResource` and `AppDefinitionUpdateRequest`.

The update path includes validation that:

- at least one field is provided,
- no value is negative,
- and `minInstances <= maxInstances`.

### Architectural Importance

This API is not the predictive scaler itself. Its importance is that it creates the control interface needed by a future predictor or external automation.

A later predictive scaling component would not need to manipulate Kubernetes resources directly. Instead, it could:

1. forecast expected demand,
2. update `minInstances` to adjust eager-start pool capacity,
3. update `maxInstances` if the total session ceiling should also change,
4. let the operator reconcile the prewarmed pool accordingly.

This is exactly the kind of separation of concerns that makes future work realistic and maintainable.

## Cross-Cutting Architecture

### End-to-End Session Startup Flow

The final system can be described as the following high-level sequence:

1. A user requests a Theia session.
2. Theia Cloud creates a `Session` resource.
3. `EagerSessionHandler` tries to serve it from the prewarmed pool.
4. `PrewarmedResourcePool` reserves a free prewarmed instance.
5. Session-specific ownership, labels, and route rules are attached.
6. `SessionEnvCollector` gathers runtime data for that session.
7. `AsyncDataInjector` waits until the bridge inside the IDE container is ready.
8. `theia-data-bridge` receives and stores the injected data.
9. Scorpio loads the runtime environment from the bridge.
10. Scorpio initializes Artemis authentication, repository access, and Theia-specific behavior.
11. The user reaches a personalized already running IDE through the updated `HTTPRoute`.

This is the most important sequence to capture in the thesis because it shows how all implemented parts interact.

## Architectural Themes

Several architectural themes run through the whole project:

### Separation of Generic and Personalized State

Prewarmed infrastructure is kept generic for as long as possible. Personalization happens only after session assignment.

### Reconciliation over Ad-hoc Mutation

Pool resources are not handled as disposable one-off artifacts. They are reconciled against target counts and app definition generations.

### Reuse of Existing Platform Structures

The solution builds on existing Theia Cloud concepts such as `AppDefinition`, `Session`, the operator, and shared ingress resources rather than replacing them wholesale.

### Fallback and Operational Robustness

Eager startup is optimized but not mandatory. The lazy path remains as fallback, reducing operational risk.

### Concurrency-Aware Control Plane Design

The control plane was explicitly hardened for bursty workloads through synchronized pool reservation, race-aware session handling, retry-based route mutation, and asynchronous follow-up work outside the hottest request path.

### Future-Proof Control Surfaces

The scaling API makes future predictive scaling an external decision problem rather than an invasive operator rewrite.

## Evaluation Snapshot

To validate the implementation, I measured session-start duration under both sequential and bursty workloads using the benchmark data in `./benchmarks/data`.

### Evaluated Scenarios

The evaluation compared three platform states:

- previous state before the implementation: lazy startup only,
- current state after the implementation: lazy startup,
- current state after the implementation: eager startup.

These states were tested in two workload patterns:

- sequential workload: `100` session starts with `10` seconds between starts,
- concurrent workload: `50` session starts triggered at random within a `20` second window.

This produced the following six benchmark scenarios:

- `100-pre-lazy-seq`: previous implementation state, lazy startup, 100 sequential starts,
- `100-post-lazy-seq`: current implementation state, lazy startup, 100 sequential starts,
- `100-post-eager-seq`: current implementation state, eager startup, 100 sequential starts,
- `50-pre-lazy-concurrent`: previous implementation state, lazy startup, 50 concurrent starts,
- `50-post-lazy-concurrent`: current implementation state, lazy startup, 50 concurrent starts,
- `50-post-eager-concurrent`: current implementation state, eager startup, 50 concurrent starts.

### Results

The benchmark results show a clear latency reduction, especially for the eager-start path:

| Scenario | Median duration | Mean duration | Max duration |
| --- | ---: | ---: | ---: |
| `100-pre-lazy-seq` | 5.59 s | 6.40 s | 12.35 s |
| `100-post-lazy-seq` | 4.18 s | 4.24 s | 8.35 s |
| `100-post-eager-seq` | 1.37 s | 1.54 s | 3.28 s |
| `50-pre-lazy-concurrent` | 18.67 s | 20.63 s | 36.31 s |
| `50-post-lazy-concurrent` | 11.58 s | 13.13 s | 23.72 s |
| `50-post-eager-concurrent` | 1.99 s | 3.73 s | 9.33 s |

Two observations are particularly important for the thesis:

- In the sequential workload, eager startup reduced the median startup time from `4.18 s` to `1.37 s` compared to the current lazy path, which corresponds to a reduction of about `67%`.
- In the concurrent workload, eager startup reduced the median startup time from `11.58 s` to `1.99 s` compared to the current lazy path, which corresponds to a reduction of about `83%`.

Compared to the previous system state before the implementation, the effect is even stronger:

- sequential median startup time improved from `5.59 s` to `1.37 s` with eager startup, about `75%` lower,
- concurrent median startup time improved from `18.67 s` to `1.99 s` with eager startup, about `89%` lower.

The current lazy path also improved compared to the previous lazy baseline:

- from `5.59 s` to `4.18 s` median in the sequential workload,
- and from `18.67 s` to `11.58 s` median in the concurrent workload.

This suggests that the implementation did not only improve startup through prewarming, but also improved the surrounding control-plane and routing behavior. That interpretation is consistent with the migration to Gateway API / Envoy Gateway and the concurrency-oriented changes in the session handling path.

## Scope and Future Work

The implemented work focuses on the enabling infrastructure that must exist before predictive scaling is worth adding:

- predictive scaling without reliable prewarming would not help enough,
- prewarming without runtime personalization would not be usable,
- and both would still be limited if routing propagation remained slow.

Therefore the implementation established the operational core first:

- robust eager startup,
- concurrency-safe handling for burst session starts,
- runtime personalization,
- practical Artemis/Theia integration,
- and an API-based control surface for scaling.

That provides a credible foundation for future predictive scaling research.

## Thesis Framing Recommendation

A coherent way to frame the work in the thesis is:

> The thesis implements the architectural basis for low-latency personalized cloud IDE sessions in educational environments. The core contribution is a production-oriented eager session startup pipeline for Theia Cloud that combines prewarmed instance pools, concurrency-safe handling of burst session starts, runtime session personalization, faster Gateway API based routing, and integration with Artemis through Scorpio. In addition, the thesis provides a scaling API that prepares the system for future predictive scaling approaches.

This framing connects all parts of the implementation into one story and explains why the project is more than a collection of isolated changes.

## Candidate Chapter Mapping for the Thesis

This implementation overview can later be transformed into thesis chapters roughly as follows:

- Background / Problem Statement
  - startup latency in cloud IDEs
  - challenge of personalizing prewarmed sessions
  - routing propagation as part of end-to-end latency
- System Design
  - Theia Cloud architecture
  - eager session startup design
  - runtime data injection architecture
  - Scorpio integration strategy
  - scaling API
- Implementation
  - `PrewarmedResourcePool` and operator handlers
  - Gateway API / Envoy Gateway routing model
  - `theia-data-bridge`
  - Scorpio changes
  - scaling API endpoints and validation
- Evaluation
  - cold vs eager startup latency
  - routing propagation improvements
  - correctness and usability of runtime personalization
  - operational behavior under limited prewarmed capacity
- Discussion / Future Work
  - predictive scaling using the scaling API
  - adaptive pool sizing
  - stronger observability and automation
