= System Design

This chapter details the system architecture designed to fulfill the requirements
outlined in the previous chapter. Adopting a "structure-first, behavior-second"
narrative, it begins by establishing the core design goals. It then introduces the
static structural boundaries of the system before detailing the dynamic behavior of
components under load. Finally, it maps these software components to their underlying
hardware and explains how persistent state and scaling are managed.

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

== System Structure

To understand how the system achieves these goals, it is necessary to first define
its static physical and logical boundaries. The architecture is distributed across
three primary environments: the Artemis Cluster, the Theia Cloud Control Plane, and
the Theia Session Runtime.

#figure(
  image("../figures/ssd4.svg", width: 100%),
  caption: [Subsystem Decomposition (UML Component Diagram)],
) <fig:subsystem-decomposition>

As illustrated in @fig:subsystem-decomposition, the *Artemis Cluster* acts as the
external consumer, requesting programming exercises and IDE sessions. The *Theia
Cloud Control Plane* resides within a Kubernetes cluster and contains the core
orchestration logic. It includes the Theia Cloud Operator, which manages the
`PrewarmedResourcePool` and eager session handlers, as well as the Gateway API and
Ingress Manager responsible for dynamic routing. Finally, the *Theia Session Runtime*
represents the isolated environment where the student's IDE executes. This runtime
contains the generic IDE container augmented with the `theia-data-bridge` and the
`Scorpio` extension, which facilitate late-binding personalization.

== Dynamic System Behavior

With the static boundaries established, the system's operation can be broken down
into three logical phases that describe how these components interact to
deliver a fast, personalized IDE session.

=== Instance Lifecycle

The foundation of the eager startup pipeline is the lifecycle of a single IDE pool
slot, managed as a Kubernetes Deployment.

#figure(
  image("../figures/state-machine.drawio.svg", width: 100%),
  caption: [Instance Lifecycle (UML State Machine Diagram)],
) <fig:state-machine>

As shown in @fig:state-machine, an instance begins in the `Provisioning` state when
the system scales up to meet the configured pool size. During this phase, Kubernetes
schedules the pod and pulls the necessary container images. Once the generic
container is running and healthy, it transitions to the `Prewarmed` state, waiting in
the pool.

When a user requests a session, the operator acquires a lock on a prewarmed instance,
moving it to the `Reserved` state. This prevents race conditions during burst loads.
The instance then enters the `Personalizing` phase, where user-specific data is
injected. Upon successful data injection, the instance becomes `Bound` to the user
and is actively used for the session. When the session ends or the instance is
destroyed (an instance reset), the underlying pod is deleted, and the deployment
controller routes the slot back to the `Provisioning` phase to guarantee a clean,
generic environment for the next user.

=== Fast-Path Session Assignment & Routing

The critical path of an eager session startup is designed to minimize perceived
latency by performing operations synchronously only when absolutely necessary.

[PLACEHOLDER: Insert Combined Sequence Diagram (Eager Startup & Routing) Here]

When a user requests a session, the Theia Cloud Operator immediately claims a
`Reserved` instance from the pool. Synchronously, the operator updates the Gateway
API (Envoy) via the Ingress Manager to route external traffic to this specific
instance. Because Envoy supports dynamic route discovery without hot restarts, this
routing update propagates rapidly. The system returns the reachable URL to the user
almost immediately, while the actual personalization of the IDE container happens in
parallel.

=== Runtime Personalization

To prevent personalization from blocking the critical path, user-specific context is
injected asynchronously after the instance is reserved.

[PLACEHOLDER: Insert Sequence Diagram (Async Data Injection) Here]

Once the instance is in the `Personalizing` state, the `AsyncDataInjector` component
within the operator begins polling the internal `theia-data-bridge` service running
inside the IDE container. It securely transmits the user's environment variables, Git
credentials, and session tokens via HTTP. Inside the container, the adapted `Scorpio`
extension operates using a `DataBridgeStrategy`. Instead of expecting credentials in
the initial process environment, Scorpio waits for the `theia-data-bridge` to signal
that the injection is complete. It then retrieves the credentials, authenticates with
Artemis, and clones the student's repository—all without requiring a container
restart.

== Hardware Software Mapping & Observability

The distributed nature of the architecture maps cleanly to the underlying Kubernetes
infrastructure. The Theia Cloud Operator, Gateway API controllers, and Scaling API
service run on the cluster's *control plane nodes* (or dedicated infrastructure
nodes). These components require minimal compute but rely heavily on the Kubernetes
API server. Conversely, the prewarmed IDE instances are scheduled on *worker nodes*,
which provide the necessary memory and CPU capacity for compilation and language
servers.

To monitor the dynamic behaviors described above, backend observability is deeply
integrated using Sentry. Incoming session-start requests are tracked as performance
transactions. Sub-operations—such as pool reservation times, route update propagation
via the Ingress Manager, and the asynchronous data injection loops—are modeled as
spans. This allows operators to track the exact timing of the fast-path assignment
and late-binding personalization without logging sensitive user payloads.

== Persistent State and Scaling Control

The system avoids external databases, persisting its operational state entirely
within Kubernetes Custom Resources (CRDs). The `AppDefinition` resource acts as the
source of truth for scaling configurations, exposing two key parameters:

- `minInstances`: Dictates the size of the eager-start pool (the number of
  `Prewarmed` instances to maintain).
- `maxInstances`: Defines the absolute ceiling for concurrent sessions allowed for
  that specific application.

[PLACEHOLDER: Insert Sequence Diagram (Scaling API / Pool Adjustment) Here]

To enable programmatic scaling, the architecture introduces a dedicated Scaling API.
This RESTful control surface allows external systems to inspect and patch these
parameters. When the `minInstances` value is updated via the API, the Kubernetes API
server persists the change, and the Theia Cloud Operator immediately reconciles the
pool—either provisioning new instances to meet anticipated demand or scaling down
excess capacity.
