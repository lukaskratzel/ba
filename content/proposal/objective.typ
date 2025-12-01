= Objectives

This thesis aims to design, implement, and evaluate a comprehensive scaling API for
cloud-based IDE deployments in educational platforms. Building upon Theia Cloud's
existing infrastructure, the work will address the identified challenges through four
primary objectives:

1. Design and implement a unified scaling API
2. Implement user binding and session management
3. Enhance container prewarming mechanisms
4. Test system performance and establish guidelines

#figure(
  image("../../figures/activity-diagram.svg"),
  caption: [Activity diagram showing the desired flow between the student and Theia
    Cloud, illustrating how prewarmed pods and user binding reduce startup delay],
) <fig:activity-diagram>

== Design and Implement a Unified Scaling API

A comprehensive API will serve as the primary interface for controlling Theia Cloud's
scaling behavior. Through endpoints for session pool adjustment, capacity
reservation, and session lifecycle management, this API enables dynamic IDE
provisioning tailored to educational workloads.

It supports programming language-specific configurations and real-time capacity
queries, forming the foundation for all subsequent objectives. The implementation
will introduce Kubernetes Custom Resource Definitions for pool configuration and REST
endpoints for pool management, with monitoring through Prometheus metrics for the
session latency, pool utilization, and resource efficiency.

== Implement User Binding and Session Management

As outlined in @fig:activity-diagram, prewarmed containers require a mechanism for
injecting user-specific configurations without compromising isolation. The binding
mechanism prevents credential leakage and ensures proper session cleanup while
supporting the Artemis Scorpio extension workflow for problem statements,
submissions, and test feedback. This work will allow the user-to-pod assignment
process to happen at runtime of the prewarmed session.

== Enhance Container Prewarming Mechanisms

Building upon Theia Cloud's existing prewarming mechanism, this objective refines
session pool management to ensure reliable instance handling across multiple
programming language configurations.

The enhanced mechanism maintains pre-initialized containers with loaded dependencies,
reducing provisioning and initialization delays while handling concurrent assignments
and preventing resource leaks. The system will replace static pool sizing with
dynamic pool controllers that can scale based on demand with configurable safety
bounds to balance responsiveness with resource efficiency.

== Test System Performance and Establish Guidelines

This objective tests the system using the existing Theia scale test infrastructure,
systematically assessing behavior under various pool configurations and load
scenarios. Experiments measure latency, utilization rates, resource efficiency, and
response times when adjusting pool sizes.

The testing establishes guidelines on prediction lead times for future predictive
scaling work, producing an operational manual documenting optimal configurations,
scaling thresholds, and best practices with empirically validated parameters. The
deliverables include baseline performance benchmarks comparing cold versus warm
starts at various percentiles, comprehensive Grafana dashboards for operational
monitoring and validated target metrics.
