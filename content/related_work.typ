= Related Work

This chapter reviews the foundational literature and recent architectural
advancements that contextualize the need for low-latency, personalized development
environments in computer science education. It first examines the pedagogical shift
towards web-based Integrated Development Environments (IDEs) and their integration
with automated assessment platforms. It then explores relevant
infrastructure optimization techniques.

== Cloud IDEs in Education

The rapid increase in student enrollments in computer science courses has made the
manual evaluation of programming assignments largely intractable, necessitating the
adoption of Automated Programming Assessment Systems (APAS)
@krusche:2018:ArtemisAutomaticAssessment. Systems such as Artemis leverage Version
Control Systems and Continuous Integration to evaluate student submissions securely
and provide immediate feedback at scale @krusche:2018:ArtemisAutomaticAssessment.
Empirical evidence demonstrates that integrating web-based coding tools with
automated feedback loops enhances student engagement, motivation, and overall
academic performance by allowing learners to iteratively improve their solutions
@benotti:2018:EffectWebbasedCoding.

To further lower the barriers to entry, particularly the time-consuming and
error-prone setup of local development environments, educational platforms are
increasingly migrating to cloud-based Integrated Development Environments (IDEs)
@frankford:2025:OnlineIntegratedDevelopment. Advanced cloud IDEs, such as Eclipse
Theia, offer feature-rich, browser-accessible interfaces that closely mirror
professional desktop tools, providing essential features like syntax highlighting and
advanced autocompletion @frankford:2025:OnlineIntegratedDevelopment. While
integrating robust IDEs into APAS platforms improves the learning experience, it
introduces resource and scalability challenges. Deploying individual containerized
environments for hundreds of concurrent students results in high memory consumption
and startup delays, which can disrupt synchronous educational activities like exams
or live labs @frankford:2025:OnlineIntegratedDevelopment.

== Prewarming and Cold-Start Mitigation

The latency associated with dynamic container provisioning is a well-documented
challenge, predominantly researched in the context of serverless computing and
Function-as-a-Service (FaaS) platforms. The time required to schedule a pod, pull an
image, and initialize the runtime environment often leads to unacceptable delays. A
widely validated mitigation strategy is container prewarming, which involves
proactively maintaining a pool of pre-initialized, generic containers
@mohan:2019:AgileColdStarts. By preparing these resources in advance, systems can bypass the
initialization overhead, reducing cold-start latency and maintaining stable response
times even as concurrent requests spike @mohan:2019:AgileColdStarts. Studies
demonstrate that pool-based prewarming strategies can reduce 99th percentile startup
latency by up to 85% @lin:2019:MitigatingColdStarts.

An alternative approach to active prewarming is using execution state snapshotting,
such as Checkpoint/Restore In Userspace (CRIU), to serialize container memory to disk
and restore it on demand. However, empirical studies reveal that the time required to
checkpoint and restore a container is linearly proportional to the size of its memory
allocation @tosic:2024:RuntimeApplicationMigration. For memory-intensive applications
like cloud IDEs, the I/O bottleneck incurred during the restoration phase makes
snapshotting less viable than maintaining actively running prewarmed pools
@tosic:2024:RuntimeApplicationMigration.

Implementing prewarming in a multi-tenant educational platform introduces the
challenge of personalization. Prewarmed containers must remain generic to be
reusable, yet a student's IDE session requires specific, sensitive context, such as
version control credentials and repository bindings. Resolving this requires
"late-binding" mechanisms, where the system claims a generic compute resource from a
prewarmed pool before it injects the specific user payload or identity
@sfiligoi:2025:ContainerLatebindingUnprivileged. Recent advancements in unprivileged
distributed computing demonstrate that Kubernetes can support late-binding through
multi-container pods and shared ephemeral storage, allowing the system to
dynamically stage user-specific configurations into running environments without
requiring container restarts
@sfiligoi:2025:ContainerLatebindingUnprivileged.
