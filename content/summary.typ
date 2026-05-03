= Conclusion and Future Work

This chapter reviews the project status by contrasting realized goals with those that
remain open, assesses the impact of the implemented architecture, and outlines
avenues for future work.

== Status

The primary objective of this thesis was to design and implement an architectural
foundation for low-latency, personalized cloud IDE sessions in educational
environments, specifically within the context of Theia Cloud and Artemis.

=== Realized Goals

The implementation achieved the core objectives set out at the beginning of the
project. First, the project implemented a robust eager session start mechanism. The
operator prewarms generic IDE instances and allows rapid, synchronized reservation.
This realizes the maintenance of prewarmed pools (#link(<fr1>)[FR1]) and dynamic
session assignment (#link(<fr2>)[FR2]) while significantly reducing provisioning
delays in line with low startup latency (#link(<qa1>)[QA1]). Second, the
runtime-personalization design resolved the contradiction between generic prewarming
and user-specific environments. The introduction of the data bridge and the
adaptation of the Scorpio extension enabled secure injection of credentials into
already-running containers, thereby fulfilling runtime data injection (#link(
  <fr3>,
)[FR3]), support for Artemis workflows (#link(<fr4>)[FR4]), and security and
isolation (#link(<qa4>)[QA4]). Third, the project fortified the control plane to
handle burst workloads. Mechanisms such as race-aware session handling, synchronized
pool reservations, and independent routing rule mutations ensure the system remains
stable during simulated load scenarios. Fourth, the migration from `ingress-nginx` to
the Kubernetes Gateway API reduced routing propagation delays, unblocking the latency
benefits of the prewarmed pool. Fifth, the project implemented a dedicated Scaling
API to expose and control the `minInstances` and `maxInstances` scaling parameters,
decoupling the mechanical scaling of the infrastructure from the logic of demand
prediction. Sixth, the project integrated detailed instrumentation into the Theia
Cloud landing page, service, and operator. Sentry transactions and spans for
session-start operations across all major system components enable operators to
diagnose timing and failures at the level of pool reservation, routing updates, and
data injection. This facilitates both iterative optimization and operational
monitoring. Taken together, these changes satisfy programmatic scaling (#link(
  <fr5>,
)[FR5]), safe concurrency handling (#link(<fr6>)[FR6]), fallback to lazy startup
(#link(
  <fr7>,
)[FR7]), correctness under concurrency (#link(<qa2>)[QA2]), scalability under burst
load (#link(<qa3>)[QA3]), and observability (#link(<qa6>)[QA6]).

=== Open Goals

While the foundational architecture is complete, certain aspects of the original
vision remain open. These objectives belonged to the initial scope but still require
refinement or validation.

First, while the evaluation benchmarked the system in a controlled and simulated
environment, a broader evaluation using real student traffic during an active
semester is necessary to validate the system's impact on user experience and
infrastructure load. Second, while the current concurrency measures prevent system
failure during bursts, extreme scenarios involving hundreds of simultaneous requests
can still bottleneck at synchronization points in the operator, particularly around
pool reservation. Further reducing these bottlenecks to maximize throughput remains
an open objective for the upper limits of scalability under burst load (#link(
  <qa3>,
)[QA3]).

== Summary

This thesis implemented the architectural basis for low-latency, personalized cloud
IDE sessions in educational environments. By transitioning Theia Cloud from a purely
lazy provisioning model to a production-oriented eager startup pipeline, the
implementation reduced session-preparation time by up to 89% under burst loads,
thereby meeting the central target of low startup latency (#link(
  <qa1>,
)[QA1]).

The benchmark results quantify this improvement. Under the sequential workload, the
eager startup pipeline reduced the median session-preparation time from 5.59s in the
original lazy baseline to 1.37s, while the optimized lazy path reached 4.18s. Under
the concurrent burst workload, the median dropped from 18.67s in the original lazy
baseline to 1.99s with eager startup, compared to 11.58s in the optimized lazy path.
These measurements show that prewarmed instance reservation removes pod scheduling
and container startup from the critical path and keeps startup latency low during
synchronized exercise starts.

The core contribution lies in showing that prewarming can support personalized
educational tools. The system combines prewarmed instance pools, a concurrency-safe
control plane, faster routing propagation, runtime data injection, and Sentry-backed
observability on the landing page, service, and operator to deliver fast access to
configured development environments that remain analyzable when latency or load
patterns shift. The Scaling API ensures that this architecture is not a static
solution but a prepared foundation ready to integrate with future predictive scaling
systems. This work enhances the usability of cloud IDEs for students while providing
administrators with the robust infrastructure needed to support large-scale,
synchronous educational activities.

== Future Work

The completed architecture opens several promising directions for future research and
engineering that extend beyond the scope of this thesis.

With the Scaling API in place, the immediate next step is to develop a predictive
scaling service. Such a service could consume historical usage data such as exercise
release schedules, exam registrations, assignment deadlines, and typical student
working hours to proactively adjust the prewarmed pool before demand spikes. A
production-ready predictor should not only optimize for latency, but include a cost
model for idle resources. This would allow administrators to define policies that
trade warm capacity against resource budgets, for example by scaling up shortly
before scheduled labs and scaling down during predictable off-hours.

A second direction is a broader evaluation under real teaching conditions. The
benchmark in this thesis used controlled sequential and burst workloads and started
eager runs with a fully populated prewarmed pool. Future evaluations should collect
data during active courses or exams, where students arrive with more irregular
interarrival times, reconnect after interruptions, and use the IDE while other
sessions are still starting. Such measurements would validate the improvement that
students perceive and reveal how the eager path behaves when real workloads mix warm
starts, lazy fallback, active language servers, repository cloning, and cluster
resource contention.

The benchmark leaves open the question of how the architecture behaves across a wider
range of deployment shapes. Future work should repeat the evaluation with multiple
`AppDefinition`s, larger cohorts, different IDE images, heterogeneous programming
languages, and smaller or larger Kubernetes clusters. This would clarify how pool
sizing guidelines depend on image size, language-server memory consumption, routing
propagation, and available cluster capacity. In particular, future work should study
workloads with hundreds of simultaneous starts to determine whether pool reservation,
the Kubernetes API, or routing updates become the dominant bottleneck at higher
scale.

Future work could refine the control plane for these larger bursts. The current
implementation prevents races and keeps the system stable, but the synchronized
reservation of prewarmed instances can still serialize parts of the startup path.
Future engineering work could investigate finer-grained locking and faster
orchestration mechanisms such as in-process orchestration for singleton operators or
external databases for replicated operators. These changes would preserve the
correctness guarantees of the current design while increasing throughput for large
exam cohorts.

The eager startup pipeline has reduced session preparation time, making client-side
latency a more significant contributor to overall startup latency. Optimizing the
browser's loading of the IDE session, asset caching, WebSocket establishment, and
initial rendering is therefore the next logical step toward improving the end-to-end
startup experience. While Sentry currently covers session-start paths in the landing
page, service, and operator, extending telemetry into the student-facing IDE would
close the remaining observability gap. Client-side tracing would capture the actual
perceived latency and help separate infrastructure delays from browser, network, and
IDE initialization costs.

The runtime personalization mechanism offers another path for future work. The data
bridge currently provides late-bound key-value data to extensions, which is
sufficient for credentials, tokens, and similar configuration values. Future versions
could extend this model beyond key-value semantics and support active instance
configuration during late binding. For example, the bridge could trigger controlled
CLI-based setup steps that generate language-specific workspace templates, configure
package managers, create toolchain files, or prepare exercise-specific project
structures only after the system has bound the session to a specific student and
assignment. These use cases would make configuration options available in prewarmed
environments that otherwise depend on user- or exercise-specific data at startup
time.


// Suggested New Claim / Detail,Section to Add,Benefit to Thesis "Response Time
// Thresholds: Define ""low latency"" using established human-computer interaction (HCI)
// limits (e.g., the 2-second rule).",3.2.2 Nonfunctional Requirements,"Instead of just
// saying ""significantly reduced"" , you can argue your 1.37s result meets specific
// pedagogical/psychological requirements for student focus.+1" "Comparison to ""State
// of the Art"" Cloud IDEs: Add a brief comparison to how commercial tools (e.g., GitHub
// Codespaces or Gitpod) handle prewarming.",5.4 Discussion,"It puts your work in
// context with industry leaders, showing that your solution for educational platforms
// is on par with professional-grade infrastructure.+1"
