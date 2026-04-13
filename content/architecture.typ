= System Design

This chapter details the system architecture designed to fulfill the requirements
outlined in the previous chapter. We begin by establishing the core design goals,
before introducing the static structural boundaries of the system and detailing the
dynamic behavior of components under load. Finally, we elaborate on the role of
observability and explain how persistent state and scaling are managed.

== Design Goals

The architecture of the eager session startup pipeline was driven by six primary
design goals, derived from the functional and non-functional requirements:

#figure(
  table(
    columns: (auto, 1fr),
    stroke: none,
    column-gutter: 1em,
    row-gutter: 0.85em,
    align: (top + left, top + left),
    [DG1],
    [
      #par(justify: true)[
        #strong[Minimize Startup Latency]: The primary objective is to reduce the
        time it takes for a requested session to become reachable. This requires
        shifting costly operations, such as pod scheduling and image pulling, out of
        the critical path of the student's request.
      ] <dg1>
    ],

    [DG2],
    [
      #par(justify: true)[
        #strong[Decouple Personalization from Provisioning]: To utilize prewarming
        effectively, the architecture must separate the generic infrastructure
        provisioning phase from the session-specific personalization phase.
        Personalization must occur dynamically at runtime.
      ] <dg2>
    ],

    [DG3],
    [
      #par(justify: true)[
        #strong[Ensure Robustness Under Burst Load]: Educational platforms frequently
        experience sudden spikes in demand. The architecture must handle high
        concurrency safely, preventing race conditions on shared resources and
        degrading gracefully when eager capacity is exhausted.
      ] <dg3>
    ],

    [DG4],
    [
      #par(justify: true)[
        #strong[Preserve Platform Compatibility]: The solution must build upon the
        existing Theia Cloud concepts (`AppDefinition`, `Session`) and integrate
        seamlessly with the Artemis learning platform. It should act as a transparent
        optimization layer.
      ] <dg4>
    ],

    [DG5],
    [
      #par(justify: true)[
        #strong[Enable Programmatic Scaling]: The system must expose an API-driven
        control surface for scaling parameters, allowing external systems or future
        machine-learning models to adjust prewarmed pool sizes based on anticipated
        demand.
      ] <dg5>
    ],

    [DG6],
    [
      #par(justify: true)[
        #strong[Support Operability]: The system must remain diagnosable in
        production. Fine-grained timing and error reporting on session-start paths in
        the landing page, service, and operator are required to validate
        optimizations, explain variance under load, and shorten incident response.
      ] <dg6>
    ],
  ),
  caption: [Design Goals],
  kind: table,
)

== System Structure

To understand how the system achieves these goals, it is necessary to first define
its static physical and logical boundaries. Addressing the goal to preserve platform
compatibility (#link(<dg4>)[DG4]), the architecture builds directly upon existing
Theia Cloud concepts rather than introducing a disruptive rewrite. It is distributed
across three primary environments: the external Artemis learning management system,
the student's browser, and the Kubernetes cluster hosting Theia Cloud.

#figure(
  image("../figures/ssd4.svg", width: 100%),
  caption: [Subsystem Decomposition Diagram. This diagram illustrates the physical
    and logical boundaries of the EduIDE architecture across three main environments:
    the external Artemis LMS, the student's browser, and the Kubernetes cluster
    hosting the Theia Cloud Service, Operator, and Prewarmed Resource Pool.],
) <fig:subsystem-decomposition>

As illustrated in @fig:subsystem-decomposition, the architecture consists of several
interconnected subsystems. The _LMS Server_ represents the external Artemis platform,
which manages the _Programming Exercise_ and acts as the primary entry point for
students. It communicates with Theia Cloud via the _Online IDE Service_ interface to
request session provisioning.

The _Student Browser_ hosts the _EduIDE_ client, which utilizes the _LMS Integration_
Scorpio to communicate with the LMS server and the _Theia Session API_ to interact
with the running IDE.

The core of the system resides within the Kubernetes cluster. The Kubernetes API
Server acts as the central control plane, managing the state of all Kubernetes
resources within the cluster. Theia Cloud is deployed as a set of components within
this cluster, as detailed in @tbl:theia-components.

#figure(
  table(
    columns: (8em, 1fr),
    stroke: none,
    inset: (x: 0.65em, y: 0.5em),
    align: (top + left, top + left),
    [*Component*], [*Description*],
    table.hline(stroke: 0.75pt),
    table.vline(x: 1, stroke: 0.75pt),
    [*Landing Page*],
    [
      #par(justify: true)[
        The client-side UI served to the student's browser that consumes the session
        management APIs exposed by the Service. It initiates session requests and
        redirects the student to the assigned IDE URL.
      ]
    ],
    table.hline(stroke: 0.4pt),
    [*Service*],
    [
      #par(justify: true)[
        The public-internet facing service exposes session management APIs to the Landing
        Page. It creates and watches custom resources via the Kubernetes API Server,
        expressing desired cluster state declaratively.
      ]
    ],
    table.hline(stroke: 0.4pt),
    [*Operator*],
    [
      #par(justify: true)[
        The central orchestration controller. It watches custom resources via the
        Resource Watch Service provided by the API Server. It translates the declarative
        descriptions into concrete Kubernetes resources, coordinating the reservation of
        prewarmed instances, updating routing rules, and managing runtime personalization
        among other tasks.
      ]
    ],
    table.hline(stroke: 0.4pt),
    [*Prewarmed Resource Pool*],
    [
      #par(justify: true)[
        Managed by the Operator, this component maintains a pool of generic,
        ready-to-use IDE instances to eliminate container startup latency from the
        critical path. It handles concurrent resource reservation and ensures the pool
        remains in a valid state.
      ]
    ],
    table.hline(stroke: 0.4pt),
    [*Routing Manager*],
    [
      #par(justify: true)[
        Responsible for dynamically updating the cluster's `HTTPRoute` resources to make
        instances externally reachable while ensuring authentication and access control.
      ]
    ],
    table.hline(stroke: 0.4pt),
    [*Theia\ Session*],
    [
      #par(justify: true)[
        The isolated runtime environment where the student's IDE executes. It contains
        the _Data Bridge_, an internal HTTP server responsible for runtime
        personalization.
      ]
    ],
  ),
  caption: [Theia Cloud Components],
  kind: table,
) <tbl:theia-components>

Together, the dedicated prewarmed pool and the continued use of the existing
`AppDefinition` and `Session` concepts serve the goal to minimize startup latency
(#link(<dg1>)[DG1]) while preserving platform compatibility (#link(
  <dg4>,
)[DG4]).

== Dynamic System Behavior

With the static boundaries established, the system's operation can be broken down
into three logical phases that describe how these components interact to deliver a
fast, personalized IDE session.

=== Instance Lifecycle

The foundation of the eager startup pipeline is the lifecycle of a single IDE pool
slot, managed as a Kubernetes Deployment.

#figure(
  image("../figures/state-machine.drawio.svg", width: 100%),
  caption: [Instance Lifecycle State Machine Diagram. It depicts the lifecycle of a
    single IDE pool slot managed as a Kubernetes Deployment, transitioning from
    generic Provisioning to a Prewarmed standby state, being Reserved upon a student
    request, undergoing Personalizing, and finally becoming Bound to an active
    session.],
) <fig:state-machine>

As shown in @fig:state-machine, an instance begins in the `Provisioning` state when
the system scales up to meet the configured pool size. During this phase, Kubernetes
schedules the pod and pulls the necessary container images if not already present.
Once the generic container is running and healthy, it transitions to the `Prewarmed`
state, waiting in the pool.

When a student requests a session, the operator acquires a lock on a prewarmed
instance, moving it to the `Reserved` state. This mechanism addresses the need for
robustness under burst load (#link(<dg3>)[DG3]), preventing race conditions when
multiple students request sessions simultaneously. The instance then enters the
`Personalizing` phase, where student-specific data is injected. Upon successful data
injection, the instance becomes `Bound` to the student and is actively used for the
session. When the session ends, the underlying deployment is reset, and the
deployment controller routes the slot back to the `Provisioning` phase to guarantee a
clean, generic environment for the next student. One exception to this rule is the
case where pool capacity is reduced while the instance is in the `Bound` state. Here,
the instance can not be deleted immediately, but only after the session has ended,
which represents a special case the prewarmed pool must handle. It's implemented by
marking the running session's underlying resources as scheduled for deletion. When
the student's session ends, the operator resets the resources.

=== Fast-Path Session Assignment and Routing

To minimize startup latency (#link(<dg1>)[DG1]), the critical path of an eager
session startup is designed to perform operations synchronously only when necessary,
shifting costly provisioning tasks out of the student's request cycle.

#figure(
  image("../figures/startup-seq.svg", width: 100%),
  caption: [Eager Session Startup Sequence Diagram. This sequence highlights the
    fast-path session assignment, showing how the Service, Operator, and Routing
    Manager collaborate to assign a prewarmed instance and route the student to it
    synchronously, while runtime personalization happens asynchronously in the
    background.],
) <fig:startup-seq>

As illustrated in @fig:startup-seq, the startup process begins when a student
requests a session (`startSession()`) from the Theia Cloud Service. The Service
creates a new `Session` resource in the Kubernetes API Server and waits for the
Operator to complete its work indicated by an update to the session resource
including the external session URL.

The Operator, watching the Session custom resource, detects the new session
(`created(session)`) and attempts to claim a generic instance from the Prewarmed
Resource Pool (`reserveInstance()`). Once an instance is successfully reserved, the
Operator instructs the Routing Manager to create a `HTTPRoute`
(`addRules(instance)`), effectively assigning an external URL to the specific
instance. Those rules also include authentication and access control to ensure only
the assigned student can access the session. This fast-path reservation is the core
realization of the eager startup design, while the fallback to lazy provisioning when
no warm slot is available ensures graceful degradation under burst load (#link(
  <dg3>,
)[DG3]).

The Operator then actively polls the external URL (`awaitExternalAvailability(url)`)
to ensure the asynchronous propagation of routing rules is complete. Only when the
URL is reachable does the Operator update the `Session` resource through the API
Server (`updateSession(url)`). This instructs the Service to respond to the student's
browser (`updated(session)`) that the session is ready, redirecting the student to
the external URL.

At this point, two parallel processes occur: the student's browser begins loading the
IDE client (`loadIDE(url)`), while the Operator simultaneously begins polling the
internal Data Bridge component (`pollDataBridge(url)`) for readiness and subsequently
injects the student's credentials and environment variables into the running IDE
instance (`personalizeIDE()`).

It is important to note that the latency of loading the IDE in the browser
(`loadIDE(url)`) after opening the provided URL is outside the optimization scope of
this thesis. The optimized path covers only the duration of the `startSession()`
call, including all infrastructure setup tasks, while the IDE's browser-side loading
time remains unaffected by the eager startup pipeline.

=== Runtime Personalization

To decouple personalization from provisioning (#link(<dg2>)[DG2]), student-specific
context is injected asynchronously only after a generic instance is reserved, keeping
the pool generic. This asynchronous injection is not merely an optimization to avoid
blocking the critical path, but a necessity dictated by an architectural constraint
of the Theia IDE: Theia extensions are only started when the student's browser loads
the session. Consequently, the student must load the session client-side for the
internal data bridge to become active and ready to receive the injected data.

Once the instance is in the `Personalizing` state, the operator begins polling the
internal Data Bridge service running inside the IDE instance. As soon as the student
connects and the bridge becomes responsive, the operator securely transmits the
student's environment variables, Git credentials, and session tokens.

The Data Bridge resolves the fundamental contradiction of prewarming: sessions must
be generic before assignment but personalized immediately afterward. It operates as a
lightweight VS Code extension that exposes a HTTP server to the operator from inside
the IDE instance. When the Operator sends the student's environment, the bridge
stores these values and persists them securely using the IDE's secret storage
mechanism. It then exposes a VS Code command that allows any other extension to
retrieve these specific variables dynamically using key-value store semantics.

Inside the container, the adapted `Scorpio` LMS extension employs a strategy pattern
to load its environment. It can initialize using either traditional process
environment variables or the newly introduced data bridge. For sessions started
generically from the prewarmed pool, the data bridge strategy is automatically chosen
by picking up the `SCORPIO_THEIA_ENV_STRATEGY` environment variable. The process
environment cannot be used to realize the late-binding personalization because it
remains static after the container is prewarmed generically. Scorpio waits for the
Data Bridge to signal that the injection is complete. It then retrieves the
credentials, authenticates with Artemis, and clones the student's repository without
requiring a container restart. This decoupling of infrastructure provisioning from
runtime personalization ensures that the prewarmed pool remains secure and reusable
while delivering a fully personalized IDE experience consistent with the goal to
preserve platform compatibility (#link(
  <dg4>,
)[DG4]).

== Observability

To support operability (#link(<dg6>)[DG6]), Sentry distributed tracing was integrated
across the landing page, service, and operator to monitor system dynamics and ensure
performance goals, providing detailed production data on stage behaviors, error
rates, and each operation's share of total startup time.

This observability guided the implementation by enabling focused, system-wide
optimizations. For example, traces revealed NGINX route rule propagation caused
startup delay for both eager and lazy sessions, allowing targeted improvements.

Session-start requests are tracked as end-to-end performance transactions.
Sub-operations, like pool reservation, Routing Manager update propagation, and
asynchronous data injection are modeled as spans. This tracks fast-path assignment
and late-binding personalization timings without logging sensitive payloads.

// TODO: Insert screenshot of Sentry eager startup trace here
// #figure(
//   image("../figures/sentry-trace.png", width: 100%),
//   caption: [Distributed trace of an eager session startup captured via Sentry. The trace
//     visualizes the end-to-end performance transaction, breaking down the total startup
//     time into distinct spans such as pool reservation, routing rule propagation, and
//     asynchronous data injection.],
// ) <fig:sentry-trace>

Such a trace delineates the subprocesses involved in provisioning. This integrated
observability benefits all future changes by establishing target metrics to prevent
performance regressions and maintain fast startup times.

== Persistent State and Scaling Control

The system avoids external databases, persisting its operational state entirely
within Kubernetes Custom Resources (CRDs). The `AppDefinition` resource acts as the
source of truth for scaling configurations. @lst:app-definition provides a concrete
example of such a configuration, detailing the container image, resource limits, and
crucially, the scaling parameters governing the prewarmed pool (#link(<dg1>)[DG1]):

#figure(
  ```yaml
  downlinkLimit: 30000
  image: ghcr.io/eduide/eduide/java-17:latest
  imagePullPolicy: IfNotPresent
  ingressHostnamePrefixes:
    - '*.webview.'
  ingressname: theia-cloud-demo-ws-route
  limitsCpu: '2'
  limitsMemory: 3000M
  maxInstances: 1000
  minInstances: 3
  monitor:
    activityTracker:
      notifyAfter: 55
      timeoutAfter: 60
    port: 3000
  mountPath: /home/project
  name: java-17-latest
  options:
    dataBridgeEnabled: 'true'
    dataBridgePort: '16281'
  port: 3000
  requestsCpu: 500m
  requestsMemory: 2000M
  timeout: 1440
  uid: 101
  uplinkLimit: 30000
  ```,
  caption: [Example `AppDefinition` Custom Resource. This declarative configuration
    acts as the source of truth for an IDE environment, specifying the container
    image, resource limits, and the `minInstances` and `maxInstances` scaling
    parameters.],
) <lst:app-definition>

As seen in the example, the `AppDefinition` exposes two key parameters for scaling:

- `minInstances`: Dictates the size of the eager-start pool (the number of
  `Prewarmed` instances to maintain).
- `maxInstances`: Defines the ceiling for concurrent sessions allowed for that
  specific application.

// no diagram here, be sure to explain well and maybe go into mechanism marking
// claimed instances as scheduled for deletion. Backreference to state machine.

To enable programmatic scaling (#link(<dg5>)[DG5]), the architecture introduces a
dedicated Scaling API that allows external systems to inspect and patch these
parameters securely. To protect these administrative operations, the API enforces
authorization using Bearer authentication with a custom admin token. This ensures
that only trusted external systems, such as future machine-learning models predicting
demand, can implement programmatic scaling logic.

The API exposes three primary endpoints under the `/service/admin/appdefinition`
path, as listed in @tbl:scaling-api.

#figure(
  table(
    columns: (auto, 1fr),
    stroke: none,
    column-gutter: 1em,
    row-gutter: 0.85em,
    align: (top + left, top + left),
    [`GET /`],
    [
      #par(justify: true)[
        Lists the current scaling settings (`minInstances` and `maxInstances`) for
        all available app definitions.
      ]
    ],

    [`GET /{name}`],
    [
      #par(justify: true)[
        Retrieves the scaling settings for a specific app definition.
      ]
    ],

    [`PATCH /{name}`],
    [
      #par(justify: true)[
        Updates the `minInstances` and/or `maxInstances` for a specific app
        definition, including applicable validation rules.
      ]
    ],
  ),
  caption: [Scaling API Endpoints under `/service/admin/appdefinition`],
  kind: table,
) <tbl:scaling-api>

When the `minInstances` value is updated via the `PATCH` endpoint, the Kubernetes API
server persists the change, and the Theia Cloud Operator reconciles the pool, either
provisioning new instances to meet anticipated demand or scaling down excess capacity
according to the state transitions defined in @fig:state-machine.
