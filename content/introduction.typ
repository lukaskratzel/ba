= Introduction

The landscape of computer science education has transformed over the past decade.
Krusche et al. note that the surge in student numbers has rendered manual assessment
of programming exercises impractical, prompting the need for automated assessment
systems @krusche:2018:ArtemisAutomaticAssessment. In response, learning management
systems like Artemis have emerged to provide automated programming exercise
assessment with quick feedback at scale @krusche:2018:ArtemisAutomaticAssessment.

Online IDE services for training, assessments, and development environments have
proliferated as learning platforms increasingly migrate their development
infrastructure to the cloud @srinivasa:2022:BadIDEaWeaponizing
@usa:2024:CloudBasedLightweightModern. These cloud-hosted environments eliminate
local setup requirements and provide consistent, standardized development experiences
to students @schmidt:2024:InclusiveLearningEnvironmentsa.

Eclipse Theia is an extensible cloud and desktop IDE platform. It provides a unified
interface for various programming languages in a browser-based environment. Theia
Cloud enables the deployment and management of Theia-based IDEs on Kubernetes at
scale. Figure @fig:ssd shows this integration. The university deploys the Theia Cloud
instance that this thesis develops and evaluates under the name EduIDE.

#figure(
  image("../figures/ssd3.svg"),
  caption: [The deployment diagram showing the integration between Artemis and Theia
    Cloud. Adapted from Schmidt @schmidt:2024:InclusiveLearningEnvironmentsa.],
) <fig:ssd>

== Problem

Despite the benefits of cloud-based IDEs like Theia Cloud, critical issues around
performance, user experience, and infrastructure scalability impede their practical
use in educational settings.

Startup delays create one core problem. When a student starts a session, the system
provisions a Kubernetes pod along with the necessary resources to host the
development session. This process can exceed 15 seconds, depending on system load and
resource availability, creating delays during assignment releases or approaching
deadlines.

Theia Cloud can maintain pools of prewarmed containers to address startup latency, an
approach Mohan et al. validated in the context of serverless functions
@mohan:2019:AgileColdStarts. Assigning users to prewarmed environments, however,
presents a challenge. Prewarmed environments must remain generic before assignment,
while each student requires personalized configurations like version control
credentials and assignment metadata. Injecting this personalization at runtime
without compromising the system's architecture adds further complexity.

== Motivation

Startup latency in cloud-based Integrated Development Environments affects
educational outcomes and the adoption of scalable learning platforms. Prewarming
offers a path forward by handling initialization tasks upfront.

When a student starts an exercise, EduIDE first checks for available prewarmed pods.
If one exists, the system skips the costly provisioning steps, including pod creation
and IDE startup. It directly binds the user environment to the ready pod. This
binding dynamically injects the necessary authentication tokens, repository
credentials, and workspace settings into the already running container.

Immediate access to development environments enhances the student learning
experience. Benotti et al. demonstrated that web-based coding tools with quick
feedback loops enhance student engagement and improve learning outcomes in
programming courses @benotti:2018:EffectWebbasedCoding. Minimal startup delays help
students maintain focus and momentum and concentrate on problem-solving.

A reliable and responsive cloud IDE infrastructure enables effective teaching
strategies. Instructors can design interactive exercises and live coding
demonstrations for entire classes with a system that supports synchronized
activities. Prewarming minimizes delays in exercise execution, which is valuable for
short in-class exercises where startup latency would otherwise consume a large
portion of the available time.

== Objectives

This thesis implements the architectural basis for low-latency personalized cloud IDE
sessions in educational environments. The core contribution is a production-oriented
eager session startup pipeline that builds upon Theia Cloud's existing
infrastructure. It combines prewarmed instance pools, concurrency-safe handling of
burst session starts, runtime session personalization, faster routing, integration
with Artemis, and server-side observability with Sentry for timing and error
visibility across the Theia Cloud system. The work addresses the identified
challenges through the following primary objectives:

#block[*Prewarmed IDE Instance Pool*: The central contribution of the eager startup
  pipeline is a dynamic pool of generic, ready-to-use IDE instances that the Operator
  reserves at session request time, bypassing the costly resource provisioning steps.
  A key challenge is ensuring correct behavior under concurrent demand. When multiple
  students request sessions simultaneously, the pool must assign each request to a
  distinct instance without severe performance degradation. The work introduces a
  reservation mechanism that serializes competing claims and recycles slots after
  sessions end, keeping the pool in a valid state at all times.]

#block[*Secure Context Injection Mechanism*: Prewarmed containers must remain generic
  until the system assigns a student, yet each session requires personalized
  credentials and repository access. To bridge this gap, the thesis introduces the
  data bridge, a runtime personalization mechanism that injects user-specific
  configuration into an already running container after assignment, decoupling the
  provisioning phase from session-specific setup.]

#block[*Dynamic Scaling Architecture*: Adjusting pool capacity in response to
  anticipated demand requires a control interface that integrates with the existing
  system. To this end, the thesis designs and implements a scaling API that allows
  operators to inspect and modify pool targets at runtime, without redeploying the
  system.]

#block[*Performance Benchmarks*: A benchmark measures session startup time under
  sequential and concurrent workloads, comparing warm and cold start paths as well as
  general performance optimizations. The results provide a quantitative basis for
  evaluating the effectiveness of the eager startup pipeline and for informing pool
  sizing decisions in production deployments.]

== Outline

The remainder of this thesis proceeds as follows: Chapter 2 provides the scientific
background and context, detailing the challenges of startup latency and runtime
personalization in cloud IDEs. Chapter 3 defines the system requirements, including
the existing system context, the functional requirements, the quality attributes, and
the dynamic models that capture the intended workflows. Chapter 4 presents the system
design, detailing the core components of the eager startup pipeline, such as the
prewarmed resource pool, runtime personalization via the data bridge, the routing
migration, observability, and the scaling API. Chapter 5 benchmarks the system's
performance, comparing startup latencies and analyzing behavior under concurrent
workloads. Finally, Chapter 6 concludes the thesis and discusses future work.
