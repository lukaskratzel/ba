= Requirements

This chapter defines the requirements and constraints of the system developed and
assessed in this thesis. The first section describes the existing system
architecture, detailing the original session startup process, the integration with
the Artemis learning platform, and the inherent limitations regarding routing and
prewarming. Following this, the proposed system is introduced by specifying the
functional and non-functional requirements necessary to achieve low-latency,
personalized cloud IDE sessions. The chapter concludes with dynamic models that
illustrate the system's core workflows and interactions under various operational
scenarios.

== Existing System

To understand the necessity and design of the proposed improvements, it is essential
to first examine the existing infrastructure of Theia Cloud and its integration with
Artemis.

=== Theia Cloud Session Startup

In the context of this thesis, Theia Cloud serves as the orchestration layer for
deploying and managing Eclipse Theia-based IDEs on Kubernetes. The system relies on
two primary concepts: the `AppDefinition`, which acts as a blueprint specifying the
IDE environment (e.g., container images, toolchains, and base configurations for a
specific programming language), and the `Session`, which represents an individual
user's active IDE instance.

Originally, Theia Cloud employed a lazy session startup path. When a student
requested a session, the operator dynamically provisioned the necessary Kubernetes
resources from scratch. This includes a Deployment, a Service and routing
configuration. While this on-demand approach ensures that resources are only consumed
when actively needed, it introduces significant startup latency. The process of
scheduling a pod and initializing the IDE environment can take upwards of 15 seconds.
In an educational setting, especially during synchronous exercises or exams, this
delay disrupts the student's workflow and degrades user experience.

=== Artemis-Theia Integration

// TODO: cite scorpio
Artemis is an interactive learning management platform. To bridge the gap between the
learning platform and the development environment, Artemis utilizes an integration
layer called Scorpio, which runs as an extension inside the IDE. Scorpio handles
critical workflows such as authenticating the user, cloning the correct exercise
repository, and synchronizing problem statements and feedback.

In the previous integration model, Scorpio assumed a classic desktop-style VS Code
environment. It expected all necessary environment variables, including
authentication tokens and Git credentials, to be present in the process environment.
While this assumption holds true for locally installed IDEs or lazily provisioned
containers where user data is available at pod creation time, it creates a
fundamental incompatibility with prewarmed environments, which must start generically
before user-specific data is known.

=== Routing and Deployment Setup

The deployment architecture of Theia Cloud leverages standard Kubernetes primitives.
Each session requires not only compute resources (Deployments) but also networking
resources (Services and Ingress/Routes) to make the IDE accessible to the student's
browser.

Routing plays a critical role in the startup time. Previously, the system relied on
`ingress-nginx` to expose sessions. When a new session was created, the operator had
to update the ingress configuration to route traffic to the newly provisioned pod.
The delay in routing propagation, the time it takes for the updated routing rules to
take effect and for the session URL to become reachable, contributed meaningfully to
the end-to-end startup latency.
// TODO: back this claim
Consequently, optimizing container startup time alone is insufficient if the
networking layer remains a bottleneck. This limitation necessitated the exploration
of more dynamic routing solutions, such as the Kubernetes Gateway API combined with
Envoy Gateway.

=== Personalization and Prewarming Constraints

Prewarming is a well-established technique to mitigate cold-start latency by
maintaining a pool of ready-to-use resources. However, applying prewarming to
educational cloud IDEs introduces a strict contradiction between latency and
personalization.

To be reusable and secure, prewarmed sessions must remain generic during their
initialization phase. They cannot be personalized at creation time because the system
does not yet know which student will be assigned to the pod. Baking user-specific
credentials or assignment metadata into a prewarmed container would violate security
and isolation constraints. Therefore, personalization must be deferred until
assignment of a generic instance to a specific user. This requires a mechanism for
runtime data injection that securely delivers sensitive information into an already
running container without requiring a restart, which would negate the latency
benefits of prewarming.

== Proposed System

To address the limitations of the existing architecture, the proposed system
introduces an eager session startup pipeline. This pipeline shifts the paradigm from
on-demand provisioning to dynamic assignment and runtime personalization, supported
by a hardened control plane and an API for automation.

=== Functional Requirements

The proposed system must fulfill the following functional requirements (FRs) to
achieve its objectives:

- *FR1 Maintain Prewarmed Pools*: The system must maintain a pool of prewarmed,
  generic IDE instances for each configured `AppDefinition`. The size of this pool
  must be configurable.
- *FR2 Dynamic Session Assignment*: Upon receiving a session request, the system must
  be able to dynamically and safely reserve an available prewarmed instance from the
  pool and assign it to the requesting user.
- *FR3 Runtime Data Injection*: The system must provide a mechanism to securely
  inject session-specific runtime data (e.g., authentication tokens, Git credentials)
  into the IDE container after it has been assigned, without requiring a container
  restart.
- *FR4 Support Artemis Workflows*: The system must adapt the Scorpio extension to
  consume the runtime-injected data, ensuring that Artemis workflows (cloning,
  submission, feedback) function correctly within the prewarmed Theia environment.
- *FR5 Expose Scaling API*: The system must expose a dedicated API to inspect and
  programmatically adjust the scaling parameters (`minInstances` and `maxInstances`)
  of an `AppDefinition`.
- *FR6 Safe Concurrency Handling*: The system must handle concurrent session starts
  safely, particularly during burst loads like the start of an exam.
- *FR7 Fallback to Lazy Startup*: If the prewarmed pool is exhausted and no warm
  instances are available, the system must gracefully fall back to the traditional
  lazy startup path, ensuring availability up to the configured maximum session
  limit.

=== Nonfunctional Requirements

In addition to the functional capabilities, the system must satisfy several
non-functional requirements (NFRs) that define its operational quality:

- *NFR1 Low Startup Latency*: The backend preparation time, measured from the initial
  API call to the Theia Cloud service until the session URL is reachable, must be
  significantly reduced compared to the lazy startup baseline.
- *NFR2 Correctness under Concurrency*: The control plane must remain robust under
  high contention. Shared resources, such as the prewarmed pool and routing objects,
  must not become corrupted or enter inconsistent states during simultaneous session
  requests.
- *NFR3 Scalability under Burst Load*: The system must maintain high throughput
  during spikes in demand and degrade gracefully via lazy fallback.
- *NFR4 Security and Isolation*: Generic prewarmed instances must not leak
  credentials. Once a session is terminated, the instance state must be destroyed
  before its resources can be returned to the pool.
- *NFR5 Maintainability*: The eager startup logic should integrate with the existing
  operator patterns. It should build upon the existing `AppDefinition` and `Session`
  concepts.
- *NFR6 Backend Observability*: The Theia Cloud service and operator must support
  production-oriented monitoring of session-start performance and failures. Critical
  control-plane and API steps must be attributable in telemetry (e.g., via
  distributed transactions and spans) so that latency and errors can be diagnosed
  without relying solely on end-to-end measurements. Sensitive data must not be
  exposed in telemetry beyond what is necessary for operations.

// TODO: choose which diagrams to use

== Dynamic Models

To illustrate how the proposed system fulfills these requirements, the following
dynamic models describe the core workflows and interactions within the architecture.

=== Use Case Model

A use case diagram maps out the interactions between the primary actors and the
system's core capabilities. The *Student* interacts with the system to request a
session and work on their programming exercises. The *Administrator* or an external
*Scaling Service* interacts with the Scaling API to adjust the pool sizes
(`minInstances` and `maxInstances`) to prepare for anticipated demand. Internally,
the system handles the complex logic of deciding between eager assignment and lazy
fallback, as well as the asynchronous injection of runtime data to personalize the
student's environment.

// TODO: Insert Use Case Diagram here
// <fig:use-case>

=== End-to-End Startup Workflow

The activity diagram in @fig:activity-diagram outlines the complete end-to-end
workflow from the moment a student requests an exercise to the point where they can
begin coding. The diagram is partitioned into swimlanes representing the *Student*,
*Artemis*, the *Theia Cloud Operator*, and the *Prewarmed IDE Container*.

When the student initiates an exercise in Artemis, a session request is sent to Theia
Cloud. The operator evaluates the `PrewarmedResourcePool`. If a generic instance is
available, it is immediately reserved. At this point, the workflow forks into two
parallel tracks:
1. *Synchronous Routing*: The operator updates the `HTTPRoute` and returns the
  reachable session URL to the student, minimizing perceived wait time.
2. *Asynchronous Personalization*: In the background, the operator collects the
  student's environment variables and triggers the `AsyncDataInjector`. This injector
  polls the `theia-data-bridge` inside the IDE container and transmits the
  credentials.

Once the data is injected, the Scorpio extension within the IDE consumes it to
authenticate with Artemis and clone the student's repository. If the prewarmed pool
is exhausted at the initial decision point, the operator falls back to the lazy
startup path, provisioning a new pod before proceeding with the routing update.

// TODO: Insert Activity Diagram here
// <fig:activity-startup>
