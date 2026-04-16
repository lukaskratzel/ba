= Requirements

This chapter defines the requirements and constraints of the system that this thesis
develops and assesses. The first section describes the existing system architecture,
detailing the original session startup process, the integration with the Artemis
learning platform, and the inherent limitations regarding routing and prewarming. The
chapter then introduces the proposed system by specifying the functional and
non-functional requirements necessary to achieve low-latency, personalized cloud IDE
sessions. The chapter concludes with dynamic models that illustrate the system's core
workflows and interactions under various operational scenarios.

== Existing System

The existing infrastructure of Theia Cloud and its integration with Artemis provide
the necessary context for the proposed improvements.

=== Theia Cloud Session Startup

Theia Cloud serves as the orchestration layer for deploying and managing Eclipse
Theia-based IDEs on Kubernetes. The system relies on two primary concepts: the
`AppDefinition` and the `Session`. The `AppDefinition` acts as a blueprint specifying
the IDE environment, including container images, toolchains, and base configurations
for a specific programming language. The `Session` represents an individual user's
active IDE instance based on an `AppDefinition`.

Originally, Theia Cloud employed a lazy session startup path. When a student
requested a session, the operator dynamically provisioned the necessary Kubernetes
resources from scratch. This includes a Kubernetes Deployment, a Service, and routing
configuration. While this on-demand approach ensures that resources are only consumed
when actively needed, it introduces significant startup latency. The process of
scheduling a pod and initializing the IDE environment can take upwards of 15 seconds.
In an educational setting, especially during synchronous exercises or exams, this
delay disrupts the student's workflow and degrades user experience.

=== Artemis-Theia Integration

Artemis is an interactive learning management platform. To bridge the gap between the
learning platform and the development environment, Artemis utilizes an integration
layer called Scorpio, which runs as an extension inside the IDE
@jandow:2024:ScorpioVisualStudio. Scorpio handles workflows such as authenticating
the user, cloning the correct exercise repository, and synchronizing problem
statements and feedback into the IDE.

In the previous integration model, Scorpio assumed a classic desktop-style VS Code
environment. It expected all necessary environment variables, including
authentication tokens and Git credentials, to be present in the process environment.
This assumption holds for locally installed IDEs or lazily provisioned containers
where user data exists at process startup time. It creates a fundamental
incompatibility with prewarmed environments, which must start generically before the
system knows the user's data.

=== Routing and Deployment Setup

The deployment architecture of Theia Cloud leverages standard Kubernetes primitives.
Each session requires not only compute resources (Deployments) but also networking
resources (Services and Ingress) to make the IDE accessible to the student's browser.

Routing plays an important role in the startup time. Previously, the system relied on
one central `ingress-nginx` controller to expose sessions. When the system created a
new session, the operator had to update the ingress configuration to route traffic to
the newly provisioned pod. The delay in routing propagation, that is, the time
required for the updated routing rules to take effect and for the session URL to
become reachable, contributed meaningfully to the end-to-end startup latency. This
delay stems from the `ingress-nginx` update mechanism, which rebuilds the
configuration model and reloads NGINX on most routing changes.#footnote[
  Ingress-NGINX Controller, _How It Works_, documentation page, accessed 7 April
  2026, #link("https://kubernetes.github.io/ingress-nginx/how-it-works/")[
    kubernetes.github.io/ingress-nginx/how-it-works/
  ].
] In contrast, Envoy-based gateways update routing state dynamically at runtime via
xDS APIs without requiring a reload, reducing route propagation latency.#footnote[
  Envoy Project Authors, _xDS Configuration API Overview_, documentation page,
  accessed 7 April 2026, #link(
    "https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/dynamic_configuration",
  )[
    envoyproxy.io docs
  ]; Envoy Gateway Maintainers, _System Design_, documentation page, accessed 7 April
  2026, #link(
    "https://gateway.envoyproxy.io/contributions/design/system-design/",
  )[
    gateway.envoyproxy.io
  ].
] Consequently, optimizing container startup time alone is insufficient if the
networking layer remains a bottleneck. This limitation necessitated the exploration
of more dynamic routing solutions, such as the Kubernetes Gateway API using Envoy
Gateway as an implementation.

=== Personalization and Prewarming Constraints

Prewarming is a well-established technique to mitigate cold-start latency by
maintaining a pool of ready-to-use resources. However, applying prewarming to
educational cloud IDEs introduces a contradiction between latency and
personalization.

Reusable and secure prewarmed sessions must remain generic during their
initialization phase. The system cannot personalize them at creation time because it
does not yet know which student will use the pod. Baking user-specific credentials or
assignment metadata into a prewarmed container would violate security and isolation
constraints.#footnote[
  Murugiah Souppaya, John Morello, and Karen Scarfone, _Application Container
  Security Guide_, NIST Special Publication 800-190, September 2017, #link(
    "https://doi.org/10.6028/NIST.SP.800-190",
  )[doi.org/10.6028/NIST.SP.800-190].
] Therefore, the system must defer personalization until it assigns a generic
instance to a specific user. This requires a mechanism for runtime data injection
that securely delivers sensitive information into an already running container
without requiring a restart, which would negate the latency benefits of prewarming.

== Proposed System

The proposed system introduces an eager session startup pipeline that addresses the
limitations of the existing architecture. This pipeline shifts provisioning work away
from the critical path of the student's request and performs it ahead of time,
supported by a hardened control plane and an API for automation.

=== Functional Requirements

The proposed system must fulfill the following functional requirements (FRs) to
achieve its objectives:

#figure(
  table(
    columns: (auto, 1fr),
    stroke: none,
    column-gutter: 1em,
    row-gutter: 0.85em,
    align: (top + left, top + left),
    [FR1],
    [
      #par(justify: true)[
        #strong[Maintain Prewarmed Pools]: The system must maintain a pool of
        prewarmed, generic IDE instances per `AppDefinition`. The size of this pool
        must be configurable.
      ] <fr1>
    ],

    [FR2],
    [
      #par(justify: true)[
        #strong[Dynamic Session Assignment]: Upon receiving a request to start a
        session, the system must be able to dynamically and safely reserve an
        available prewarmed instance from the pool and assign it to the requesting
        user.
      ] <fr2>
    ],

    [FR3],
    [
      #par(justify: true)[
        #strong[Runtime Data Injection]: The system must provide a mechanism to
        securely inject session-specific runtime data like authentication tokens and
        Git credentials into the IDE container after the system assigns the instance,
        without requiring a container restart.
      ] <fr3>
    ],

    [FR4],
    [
      #par(justify: true)[
        #strong[Support Artemis Workflows]: The system must adapt the Scorpio
        extension to consume the runtime-injected data, ensuring that Artemis
        workflows function correctly within the prewarmed IDE environment.
      ] <fr4>
    ],

    [FR5],
    [
      #par(justify: true)[
        #strong[Expose Scaling API]: The system must expose a dedicated API to
        inspect and programmatically adjust the scaling parameters (`minInstances`
        and `maxInstances`) of an `AppDefinition`.
      ] <fr5>
    ],

    [FR6],
    [
      #par(justify: true)[
        #strong[Safe Concurrency Handling]: The system must handle concurrent session
        starts safely, particularly during burst loads like the start of an exam.
      ] <fr6>
    ],

    [FR7],
    [
      #par(justify: true)[
        #strong[Fallback to Lazy Startup]: If the prewarmed pool runs empty, the
        system must gracefully fall back to the traditional lazy startup path,
        ensuring availability up to the configured maximum session limit.
      ] <fr7>
    ],
  ),
  caption: [Functional Requirements],
  kind: table,
)

=== Nonfunctional Requirements

In addition to the functional capabilities, the system must satisfy several
non-functional requirements (NFRs) that define its operational quality:

#figure(
  table(
    columns: (auto, 1fr),
    stroke: none,
    column-gutter: 1em,
    row-gutter: 0.85em,
    align: (top + left, top + left),
    [NFR1],
    [
      #par(justify: true)[
        #strong[Low Startup Latency]: The session preparation time, measured from the
        initial API call to the Theia Cloud service until the session URL is
        reachable, must be significantly reduced compared to the lazy startup
        baseline.
      ] <nfr1>
    ],

    [NFR2],
    [
      #par(justify: true)[
        #strong[Correctness under Concurrency]: The control plane must remain robust
        under high contention. Shared resources, such as the prewarmed pool and
        routing objects, must not become corrupted or enter inconsistent states
        during simultaneous session requests.
      ] <nfr2>
    ],

    [NFR3],
    [
      #par(justify: true)[
        #strong[Scalability under Burst Load]: The system must maintain high
        throughput during spikes in demand and degrade gracefully via lazy fallback
        without rejecting requests.
      ] <nfr3>
    ],

    [NFR4],
    [
      #par(justify: true)[
        #strong[Security and Isolation]: Generic, prewarmed instances must not leak
        credentials. Once a session ends, the system must destroy the instance state
        before it returns the resources to the pool.
      ] <nfr4>
    ],

    [NFR5],
    [
      #par(justify: true)[
        #strong[Maintainability]: The eager startup logic should integrate with the
        existing operator patterns. It should build upon the existing `AppDefinition`
        and `Session` concepts.
      ] <nfr5>
    ],

    [NFR6],
    [
      #par(justify: true)[
        #strong[Observability]: The Theia Cloud landing page, service, and operator
        must support production-oriented monitoring of session-start performance and
        failures. Telemetry must attribute critical control-plane, API, and
        user-facing entry steps so that operators can diagnose latency and errors
        without relying solely on end-to-end measurements. Sensitive data must not
        appear in telemetry beyond what operations require.
      ] <nfr6>
    ],
  ),
  caption: [Non-Functional Requirements],
  kind: table,
)

== Dynamic Models

The following dynamic models describe the core workflows and interactions within the
architecture, illustrating how the proposed system fulfills these requirements.

=== Use Case Model

#figure(
  image("../figures/use-case.svg"),
  caption: [Use case diagram for the prewarming and session management system.],
) <fig:use-case>

@fig:use-case identifies two primary actors. The _Student_ initiates the session
lifecycle by requesting an IDE session, connecting to the provisioned environment,
and ending the session once work is complete. These use cases correspond to the
functional requirements for dynamic session assignment (#link(<fr2>)[FR2]), runtime
data injection (#link(<fr3>)[FR3]), and lazy fallback (#link(<fr7>)[FR7]).

The _Administrator_ operates the system's scaling and monitoring surface. Configuring
the pool size maps to the scaling API requirement (#link(<fr5>)[FR5]), allowing
operators to adjust prewarmed capacity ahead of anticipated demand. Monitoring pool
utilization and resource usage support the observability requirement (#link(
  <nfr6>,
)[NFR6]), giving operators visibility into whether the prewarmed pool has adequate
capacity and how the infrastructure consumes resources under load.

=== End-to-End Startup Workflow

#figure(
  image("../figures/activity-diagram.svg"),
  caption: [Activity diagram showing the desired flow between the student and Theia
    Cloud, illustrating how prewarmed pods and user binding reduce startup delay.],
) <fig:activity-diagram>

@fig:activity-diagram outlines the end-to-end workflow from the moment a student
starts an exercise to the point where they can work on the exercise. When a student
requests a session, Theia Cloud checks for an available prewarmed instance. If one
exists, the system skips provisioning and directly binds the user environment to the
ready-to-use instance. Otherwise, the system lazily provisions a new instance before
proceeding.

This workflow implements the functional requirements. The system relies on continuous
pool maintenance (#link(<fr1>)[FR1]) to ensure ready instances. Upon a request, it
dynamically assigns a free instance (#link(<fr2>)[FR2]) and injects session-specific
data at runtime (#link(<fr3>)[FR3]) to avoid latency-inducing container restarts.
This data enables the Artemis integration to authenticate and clone repositories
(#link(<fr4>)[FR4]). To support many students starting simultaneously, these
assignment steps must handle concurrency safely (#link(
  <fr6>,
)[FR6]).

Eager provisioning minimizes idle time for the student. The system reduces latency
and allows productive work to begin sooner than in a lazy setup by shifting
initialization before the request.

If the prewarmed pool runs empty, the system falls back to lazy startup (#link(
  <fr7>,
)[FR7]), provisioning a new session from scratch. This fallback guarantees
availability up to the cluster's maximum capacity, ensuring students are not rejected
because the warm pool is temporarily exhausted.
