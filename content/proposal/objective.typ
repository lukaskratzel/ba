= Objectives

This thesis aims to design, implement, and evaluate a comprehensive scaling API for
cloud-based IDE deployments in educational platforms. Building upon Theia Cloud's
existing infrastructure, the work will address the identified challenges through four
primary objectives:

1. Design and implement a unified scaling API
2. Enhance container prewarming mechanisms to eliminate cold-start delays
3. Implement User Binding and Session Management
4. Evaluate system performance and establish operational guidelines

#figure(
  image("../../figures/activity-diagram.svg"),
  caption: [Activity diagram showing the desired flow between the student and Theia
 Cloud, illustrating how prewarmed pods and user binding eliminate startup
 delays],
) <fig:activity-diagram>

== Design and Implement a Unified Scaling API

This objective creates a comprehensive API as the primary interface for controlling
Theia Cloud's scaling behavior. The API enables dynamic IDE provisioning through
endpoints for session pool adjustment, capacity reservation, and session lifecycle
management.

It supports programming language-specific configurations and real-time capacity
queries, forming the foundation for all subsequent objectives. The implementation
will introduce Kubernetes Custom Resource Definitions for pool configuration and REST
endpoints for pool management, with monitoring through Prometheus metrics for the session
latency, pool utilization, and resource efficiency.

== Enhance Container Prewarming Mechanisms to Eliminate Cold-Start Delays

Building upon Theia Cloud's existing prewarming mechanism, this objective refines
session pool management to ensure reliable instance handling across multiple
programming language configurations. As shown in @fig:activity-diagram, when a
The student starts an exercise, the system first checks for available prewarmed pods
before provisioning new instances.

The enhanced mechanism maintains pre-initialized containers with loaded dependencies,
reducing provisioning and initialization delays while handling concurrent assignments
and preventing resource leaks. The system will replace static pool sizing with
dynamic pool controllers that automatically scale based on utilization patterns,
implementing intelligent scale-up and scale-down policies with configurable safety
bounds to balance responsiveness with resource efficiency.

== Implement User Binding and Session Management

This objective addresses injecting user-specific configurations into prewarmed
containers without compromising isolation. As illustrated in @fig:activity-diagram,
when students launch IDEs from Artemis, the system dynamically binds them to pool
containers, injecting authentication tokens, repository credentials, and workspace
settings.

The binding mechanism prevents credential leakage and ensures proper session cleanup
while supporting the Artemis Scorpio extension workflow for problem statements,
submissions, and test feedback. This work will allow the user-to-pod assignment
process to happen at runtime of the prewarmed session.

== Evaluate System Performance and Establish Operational Guidelines

This objective evaluates the system using the existing Theia scale test
infrastructure, systematically assessing behavior under various pool configurations
and load scenarios. Experiments measure latency, utilization rates, resource
efficiency, and response times when adjusting pool sizes.

The evaluation establishes guidelines on prediction lead times for future predictive
scaling work, producing an operational manual documenting optimal configurations,
scaling thresholds, and best practices with empirically validated parameters. The
deliverables include baseline performance benchmarks comparing cold versus warm
starts at various percentiles, comprehensive Grafana dashboards for operational
monitoring and validated target metrics.
