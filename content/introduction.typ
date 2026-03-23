= Introduction

The landscape of computer science education has transformed over the past decade.
Krusche et al. note that the surge in student numbers has rendered manual assessment
of programming exercises impractical, prompting the need for automated assessment
systems @kruscheArtemisAutomaticAssessment2018. In response, platforms like Artemis
have emerged to provide automatic programming exercise assessment with quick feedback
at scale @kruscheArtemisAutomaticAssessment2018.

Online IDE services for training, assessments, and development environments have
proliferated as learning platforms increasingly migrate their development
infrastructure to the cloud @srinivasaBadIDEaWeaponizing2022
@usa:2024:CloudBasedLightweightModern. These cloud-hosted environments eliminate
local setup requirements and provide consistent, standardized development experiences
to students @schmidtInclusiveLearningEnvironments2024.

Eclipse Theia is an extensible cloud and desktop IDE platform. It provides a unified
interface for various programming languages in a browser-based environment. Theia
Cloud enables the deployment and management of Theia-based IDEs on Kubernetes at
scale. Artemis integrates Theia as shown in @fig:ssd.

#figure(
  image("../figures/ssd3.svg"),
  caption: [The deployment diagram showing the integration between Artemis and Theia
    Cloud. Adapted from Schmidt @schmidtInclusiveLearningEnvironments2024.],
) <fig:ssd>

== Problem

Despite the benefits of cloud-based IDEs like Theia Cloud, critical issues around
performance, user experience, and infrastructure scalability impede their practical
use in educational settings.

One core problem is rooted in startup delays. When a student starts a session, the
system provisions a Kubernetes pod along with the necessary resources to host the
development session. This process can exceed 15 seconds, depending on system load and
resource availability, creating delays during assignment releases or approaching
deadlines.

To address startup latency, Theia Cloud can maintain pools of prewarmed containers,
an approach validated by Mohan et al. in the context of serverless functions
@mohanAgileColdStarts2019. However, assigning users to prewarmed environments
presents a significant challenge. Prewarmed environments must remain generic before
assignment, while each student requires personalized configurations like version
control credentials and assignment metadata. Technically, injecting this
personalization at runtime without compromising the system's architecture poses a
significant challenge.

== Motivation

Addressing the startup latency issues in cloud-based Integrated Development
Environments is important from a scientific perspective, but also for improving
educational outcomes and driving adoption of scalable learning platforms. Prewarming
offers a solution by handling significant initialization tasks upfront.

#figure(
  image("../figures/activity-diagram.svg"),
  caption: [Activity diagram showing the desired flow between the student and Theia
    Cloud, illustrating how prewarmed pods and user binding reduce startup delay.],
) <fig:activity-diagram>

@fig:activity-diagram illustrates this approach. When a student starts an exercise,
Theia Cloud first checks for available prewarmed pods. If one exists, the system
skips the costly provisioning steps including pod creation and IDE startup. It
directly binds the user environment to the ready pod. This binding dynamically
injects the necessary authentication tokens, repository credentials, and workspace
settings into the already running container.

For students, immediate access to development environments can enhance their learning
experience. Research by Benotti et al. demonstrated that web-based coding tools that
provide quick feedback significantly enhance student engagement and improve learning
outcomes in programming courses @benottiEffectWebbasedCoding2018. By minimizing
startup delays, students can maintain focus and momentum, allowing them to focus on
problem-solving.

From an instructor's viewpoint, a reliable and responsive cloud IDE infrastructure
enables effective teaching strategies. With a system capable of supporting
synchronized activities, instructors can design interactive exercises and live coding
demonstrations for entire classes. Prewarming minimizes delays in exercise
conduction, which is especially valuable for short in-class exercises where startup
latency would otherwise consume a significant portion of the available time.

== Objectives and Contributions

This thesis implements the architectural basis for low-latency personalized cloud IDE
sessions in educational environments. Building upon Theia Cloud's existing
infrastructure, the core contribution is a production-oriented eager session startup
pipeline that combines prewarmed instance pools, concurrency-safe handling of burst
session starts, runtime session personalization, faster routing, and integration with
Artemis.

The work addresses the identified challenges through the following primary
objectives:

1. *Eager Session Start:* Enhance the container prewarming mechanisms to ensure
  reliable instance handling. The system maintains pools of pre-initialized
  containers and reserves them for incoming sessions, reducing provisioning delays
//  while gracefully falling back to lazy startup when warm
// capacity is exhausted.

2. *Runtime Personalization and Integration:* Implement user binding and session
  management by injecting user-specific configurations into already running IDE
  containers. A dedicated data bridge extension enables this runtime personalization.
// which is then consumed by the Artemis Scorpio extension to initialize
// authentication and repository access without requiring a restart.

3. *Concurrency and Routing Optimizations:* Harden the control plane to safely handle
  burst workloads, such as exam starts. Additionally, migrate the routing layer to
  the Kubernetes Gateway API to reduce route update propagation latency contributing
  to session startup delay.

4. *Scaling API:* Design and implement a scaling API that exposes relevant scaling
  parameters. This API serves as the control interface for adjusting the eager-start
  pool capacity.

5. *Benchmark:* Assess the system's performance, comparing cold versus eager startup
  latency and operational behavior under concurrent load.

== Outline

The remainder of this thesis is structured as follows: Chapter 2 provides the
background and context, detailing the challenges of startup latency and runtime
personalization in cloud IDEs. Chapter 3 presents the system design, including the
architecture of eager session startup, runtime data injection, and the scaling API.
Chapter 4 details the implementation of the core components, such as the prewarmed
resource pool, the data bridge, and the routing migration. Chapter 5 benchmarks the
system's performance, comparing startup latencies and analyzing behavior under
concurrent workloads. Finally, Chapter 6 concludes the thesis and discusses future
work, including the potential for predictive scaling.
