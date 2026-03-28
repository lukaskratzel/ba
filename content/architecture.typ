= System Design

This chapter details the system architecture designed to fulfill the requirements
outlined in the previous chapter. It begins by establishing the core design goals
that guided the architectural decisions. Subsequently, it breaks down the system into
its primary subsystems, detailing the internal components of the Theia Cloud
Operator, the routing layer, and the IDE runtime. The chapter then maps these
software components to their underlying hardware and infrastructure environments.
Finally, it explains how persistent state is managed, how scaling parameters are
controlled to enable programmatic scaling, and how backend observability is wired
into the service and operator.

== Design Goals

The architecture of the eager session startup pipeline was driven by six primary
design goals, directly derived from the functional and non-functional requirements:

1. *Minimize Startup Latency*: The primary objective is to reduce the time it takes
  for a requested session to become reachable. This requires shifting costly
  operations, such as pod scheduling and image pulling, out of the critical path of
  the user's request.
2. *Decouple Personalization from Provisioning*: To utilize prewarming effectively,
  the architecture must strictly separate the generic infrastructure provisioning
  phase from the user-specific personalization phase. Personalization must occur
  dynamically at runtime.
3. *Ensure Robustness Under Burst Load*: Educational platforms frequently experience
  sudden spikes in demand. The architecture must handle high concurrency safely,
  preventing race conditions on shared resources and degrading gracefully when eager
  capacity is exhausted.
4. *Preserve Platform Compatibility*: The solution must build upon the existing Theia
  Cloud concepts (`AppDefinition`, `Session`) and integrate seamlessly with the
  Artemis learning platform. It should act as an optimization layer rather than a
  disruptive rewrite.
5. *Enable Programmatic Scaling*: The system must expose a clear, API-driven control
  surface for scaling parameters, allowing external systems or future
  machine-learning models to adjust prewarmed pool sizes based on anticipated demand.
6. *Support Operability*: The system must remain diagnosable in production.
  Fine-grained timing and error reporting on session-start paths in the service and
  operator are required to validate optimizations, explain variance under load, and
  shorten incident response.

== Subsystem Decomposition

The proposed architecture is composed of several interacting subsystems, spanning
from the Kubernetes control plane down to the extensions running inside the IDE
container.

// TODO: Insert a high-level Component Diagram here.
// The diagram should show:
// - Theia Cloud Operator (containing PrewarmedResourcePool, EagerSessionHandler, AsyncDataInjector)
// - Gateway API / Envoy Gateway (handling HTTPRoutes)
// - Prewarmed IDE Pod (containing theia-data-bridge and Scorpio extension)
// - Artemis (as the external caller/consumer)
// <fig:architecture-components>

=== Theia Cloud Operator

The Theia Cloud Operator is the central orchestrator of the system. It has been
extended with several new components to manage the eager startup lifecycle:

- *PrewarmedResourcePool*: This is the core stateful abstraction for eager startup.
  It is responsible for maintaining the pool of generic instances for each
  `AppDefinition`. It handles the creation of prewarmed resources (Deployments and
  Services), reconciles the pool to match the target `minInstances`, and manages the
  safe, synchronized reservation of instances to prevent race conditions during burst
  loads.
- *EagerSessionHandler*: When a new `Session` resource is created, this handler
  attempts to serve it using the `PrewarmedResourcePool`. It orchestrates the
  transition of a generic instance into a user-bound session by attaching ownership
  labels and triggering the routing updates. If the pool is empty, it delegates to
  the fallback lazy startup handler.
- *AsyncDataInjector*: To prevent personalization from blocking the critical path,
  this component operates asynchronously. Once an instance is reserved, it polls the
  IDE container's internal service and securely transmits the collected user
  environment variables via HTTP.

=== Routing Layer

To address the latency introduced by routing propagation, the architecture migrates
from `ingress-nginx` to the Kubernetes Gateway API, utilizing Envoy Gateway as the
controller.

The decision to replace the legacy Ingress controller is rooted in the fundamental
architectural differences in how NGINX and Envoy handle dynamic configuration
updates. According to official project documentation, `ingress-nginx` derives an
`nginx.conf` file from Kubernetes resources; any effective configuration change
requires the controller to rebuild the model from scratch and trigger a proxy reload
@ingress-nginx-docs. Under high churn---such as concurrent session starts during an
exam---these reload cycles can compound, leading to operational bottlenecks and propagation delays @ingress-nginx-issues.

By contrast, the Envoy proxy supports runtime routing updates without requiring a hot
restart. This is achieved through the Route Discovery Service (RDS) and the broader
xDS protocol suite, which allows configuration state to be swapped in gracefully
@envoy-docs.

While peer-reviewed academic literature directly comparing these implementations is
sparse, independent Gateway API benchmarks provide strong quantitative support for
this architectural shift. In large-scale route propagation tests, Envoy Gateway has
demonstrated lower baseline propagation delays compared to NGINX-based
implementations @gateway-api-bench-part2. This
dynamic configuration capability is essential for minimizing the time between a
prewarmed pod reservation and the session becoming reachable to the student.

- *Ingress Manager:* This component centralizes operations on shared `HTTPRoute`
  resources. Instead of creating a dedicated ingress object for every session, the
  manager appends path-specific routing rules to a single, shared `HTTPRoute`. This
  approach aligns with Envoy's dynamic configuration capabilities, significantly
  reducing the time it takes for a newly assigned session to become externally
  reachable.

=== IDE Runtime Components

The final subsystem resides inside the prewarmed IDE container itself, bridging the
gap between the generic infrastructure and the user's specific context.

- *theia-data-bridge*: This is a lightweight, custom VS Code/Theia extension running
  inside the container. It exposes a minimal local HTTP server that listens for data
  from the `AsyncDataInjector`. Once it receives the user's environment variables
  (e.g., tokens, Git configuration), it stores them securely using the IDE's secret
  storage mechanisms and makes them available to other extensions.
- *Scorpio Extension*: The existing Artemis integration extension was adapted to
  support the prewarming paradigm. Instead of assuming credentials are present in the
  process environment at startup, Scorpio is configured to use a
  `DataBridgeStrategy`. It waits for the `theia-data-bridge` to signal that data has
  been injected, retrieves the necessary credentials, and only then proceeds to
  authenticate with Artemis and clone the student's repository.

// TODO: Insert a Sequence Diagram here.
// The diagram should illustrate the "End-to-End Session Startup Flow" (Happy Path).
// Lifelines: Student/Artemis, Theia Cloud Operator, Gateway API, IDE Container.
// Key interactions to highlight:
// 1. Operator reserves instance synchronously.
// 2. Operator updates HTTPRoute (Gateway API) AND simultaneously triggers AsyncDataInjector.
// 3. Gateway API returns reachable URL to Student.
// 4. AsyncDataInjector sends POST to theia-data-bridge.
// 5. Scorpio reads from bridge and clones repo.
// This diagram proves NFR1 by showing the URL is returned before personalization finishes.
// <fig:architecture-sequence>

== Observability (Sentry)

Backend observability is implemented with *Sentry* for the Theia Cloud REST service
and the operator. Incoming session-start requests are tied to *performance
transactions*; sub-operations are modeled as *spans* so that wall-clock time is
attributed to concrete steps—for example pool lookup and reservation, Kubernetes
resource mutations, `HTTPRoute` updates via the ingress manager, and the asynchronous
data-injection loop toward the IDE pod.

This complements the aggregate benchmark in Chapter~5: end-to-end latency shows
whether the system is fast enough, while Sentry shows *where* time is spent when
regressions or tail latencies appear. Errors and slow operations are correlated with
release and deployment context (e.g., service version, cluster environment) without
logging full session payloads. Credentials and other injected secrets are excluded
from Sentry payloads; span names and tags emphasize operational phases rather than
user-specific content, in line with NFR6 (Backend Observability).

== Hardware Software Mapping

The system is designed to run within a Kubernetes cluster, leveraging its distributed
nature for high availability and scalability.

- *Control Plane Nodes*: The Theia Cloud Operator, the Gateway API controllers (Envoy
  Gateway), and the Scaling API service run on the cluster's control plane or
  dedicated infrastructure nodes. These components require minimal compute resources
  but rely heavily on the Kubernetes API server for state management and resource
  watching.
- *Worker Nodes*: The prewarmed IDE instances (Deployments and Pods) are scheduled on
  the cluster's worker nodes. Because IDE sessions are memory-intensive, these nodes
  provide the bulk of the compute capacity. The separation of external services (for
  user traffic via the Gateway) and internal services (for the `AsyncDataInjector` to
  reach the `theia-data-bridge`) ensures that administrative traffic remains isolated
  within the cluster network.
- *Client Hardware*: The student interacts with the system entirely through a
  standard web browser. The local hardware is only responsible for rendering the DOM
  and executing the frontend JavaScript of the Theia IDE, while all compilation,
  language servers, and file system operations remain on the Kubernetes worker nodes.

== Persistent State and Scaling Control

The architecture sticks to Kubernetes native patterns by avoiding external databases
for operational state. Instead, the system's state is persisted entirely within
Kubernetes Custom Resources (CRDs).

The `AppDefinition` resource acts as the source of truth for scaling configurations.
It exposes two distinct parameters that govern the system's capacity:

- `minInstances`: This parameter controls the size of the eager-start pool. It
  dictates how many generic, prewarmed instances the `PrewarmedResourcePool` must
  maintain.
- `maxInstances`: This parameter defines the absolute ceiling for concurrent sessions
  allowed for that specific `AppDefinition`.

The interval between `minInstances` and `maxInstances` represents the capacity that
can still be served, but only through the fallback lazy startup path.

To facilitate future automation, the architecture introduces a dedicated Scaling API.
This RESTful service allows external systems to inspect and patch these parameters
programmatically. When an external service updates the `minInstances` via the API,
the Kubernetes API server persists the change, and the Theia Cloud Operator
immediately reacts by reconciling the prewarmed pool, either provisioning new
instances to meet anticipated demand or safely scaling down excess capacity. This
separation of concerns ensures that the potential logic of predicting demand is
decoupled from scaling of the infrastructure.
