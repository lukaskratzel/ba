= Schedule

The thesis will span approximately 26 weeks from October 2024 to May 2025. The work is organized into seven iterations of 3-4 weeks each, following agile principles where each iteration delivers measurable, integrated features. The schedule focuses on incremental development and validation, with continuous integration into the existing Theia Cloud and Artemis infrastructure.

== Iteration 1: Foundation and Baseline Metrics (Weeks 1-3)

- Set up development environment with local Kubernetes cluster (Minikube/k3s) running Theia Cloud
- Deploy existing Theia scale test infrastructure and establish baseline performance measurements
- Instrument Theia Cloud operator and service to collect session startup telemetry (cold start times, image pull duration, container initialization time)
- Implement metrics collection for eager vs lazy provisioning utilization
- Analyze existing codebase focusing on `EagerStartAppDefinitionAddedHandler`, `EagerSessionHandler`, and session lifecycle

*Deliverable:* Dashboard displaying current performance metrics and prewarm pool utilization rates.

== Iteration 2: Basic Prewarming Pool Enhancement (Weeks 4-7)

- Extend `EagerStartAppDefinitionAddedHandler` to support downscaling when `minInstances` decreases
- Implement deterministic selection policy for removing idle prewarmed containers
- Add health checks to verify prewarmed containers are fully initialized before marking them available
- Implement monitoring dashboards showing warm pool sizes, utilization, and binding latencies
- Create integration tests validating pool scaling behavior under load

*Deliverable:* Enhanced prewarming system that dynamically scales pools up and down based on configured `minInstances`.

== Iteration 3: Secure User Binding and Session Management (Weeks 8-11)

- Harden `EagerSessionHandler` user binding process with readiness checks for OAuth2 proxy configuration propagation
- Implement session state tracking to differentiate between provisioning, binding, ready, and active states
- Add validation that ingress rules and authentication policies are fully applied before exposing session URLs
- Extend session API to report detailed status during provisioning
- Test user isolation and security properties under concurrent session launches

*Deliverable:* Secure binding mechanism ensuring prewarmed containers cannot be accessed prematurely or by unauthorized users.

== Iteration 4: Demand Forecasting Service (Weeks 12-16)

- Design and implement standalone forecasting service with REST API for demand prediction
- Develop baseline forecasting models (time-of-day/week moving average, exponential smoothing)
- Implement historical session data collection from Theia Cloud operator logs and session status
- Create data pipeline aggregating launches per time bucket, app definition, and course identifier
- Validate forecast accuracy against held-out historical data from Artemis deployment
- Implement forecast evaluation metrics (MAE, RMSE, coverage at various confidence levels)

*Deliverable:* Forecasting service generating hourly demand predictions per `AppDefinition` with confidence intervals.

== Iteration 5: Predictive Scaling Controller (Weeks 17-19)

- Implement controller that consumes forecasts and updates `AppDefinition.spec.minInstances`
- Add safety margin calculations based on forecast confidence and service level objectives
- Implement rate-limiting to prevent thrashing and respect `maxInstances` constraints
- Create manual override mechanism for special events (exams, course-wide deadlines)
- Integrate controller with Theia Cloud REST API or direct Kubernetes API for updating resources

*Deliverable:* Automated predictive scaling system adjusting warm pools based on forecasted demand.

== Iteration 6: Artemis Integration and Signal Enhancement (Weeks 20-22)

- Design and implement webhook endpoints for Artemis to signal assignment releases and deadlines
- Extend forecasting service to incorporate Artemis course schedules and metadata
- Implement landing page traffic monitoring as leading indicator for demand spikes
- Add support for per-course forecasting to handle different usage patterns across courses
- Create configuration interface for instructors to pre-announce synchronized events

*Deliverable:* Integrated system that reacts to Artemis events and course schedules to optimize warm pool sizes.

== Iteration 7: Comprehensive Evaluation and Optimization (Weeks 23-26)

- Execute large-scale performance tests using Theia scale test infrastructure (100+ concurrent sessions)
- Measure P50/P95/P99 startup latencies comparing baseline, static prewarming, and predictive scaling
- Analyze prewarm utilization rates, forecast accuracy, and resource efficiency metrics
- Test system behavior during simulated educational events (synchronized class launches, deadline rushes)
- Optimize forecasting parameters and pool scaling policies based on evaluation results
- Document deployment configuration and operational procedures

*Deliverable:* Complete evaluation report with performance comparisons and validated predictive scaling system ready for production deployment.
