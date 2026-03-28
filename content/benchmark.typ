= Benchmark

This chapter benchmarks the implemented system architecture to determine the
effectiveness of the eager session startup pipeline and optimizations in the lazy
pipeline. It details the benchmarks design, outlines the specific objectives,
presents the quantitative results, and discusses the implications of these findings
for educational cloud IDE deployments.

== Design

The benchmark was designed to systematically compare the performance of the proposed
architecture against the previous implementation state.

=== Benchmark Environment and Workloads

The benchmarks were executed against a dedicated Kubernetes cluster running the Theia
Cloud infrastructure. To simulate realistic usage patterns, two distinct workload
scenarios were defined:

1. *Sequential Workload*: 100 session starts triggered sequentially with a 10-second
  delay between each request. This scenario represents a steady, predictable flow of
  students starting their exercises, allowing for the measurement of baseline system
  latency without the interference of resource contention.
2. *Concurrent Workload (Burst)*: 50 session starts triggered at random intervals
  within a 20-second window. This scenario simulates a burst event, such as the
  beginning of an exam or a synchronized lab session, testing the control plane's
  ability to handle high concurrency and shared resource contention.

=== Baseline and Comparison Setup

For each workload scenario, the system was benchmarked in three different states to
isolate the impact of specific architectural changes:

- *Lazy before optimization (Baseline)*: The previous system state utilizing purely
  lazy startup and `ingress-nginx` for routing.
- *Lazy after optimization*: The current system state utilizing lazy startup, but
  benefiting from the new Gateway API routing layer and concurrency-hardened control
  plane. On top, many small optimizations were applied throughout the pipeline.
- *Eager*: The optimized target state utilizing the eager session startup pipeline
  alongside the new routing layer.

=== Measurement Boundary

The latency measured in this benchmark represents the *end-to-end session-preparation
time*.

The timer starts when the initial API call is made to the Theia Cloud service to
request a session. The timer stops when the session has been fully prepared, the
runtime data injection has been scheduled, the routing rules have propagated, and the
session URL is externally reachable.

*Crucially, this measurement does not include the client-side browser loading time.*
The time taken for the student's browser to download the IDE assets, render the DOM,
and execute the frontend JavaScript is outside the optimization scope of this thesis
and is therefore excluded from the reported durations.

During development and analysis, *Sentry* performance data from the Theia Cloud
service and operator (transactions and spans along session-start paths) was used to
interpret benchmark outcomes—for example to confirm which sub-steps dominate latency
or widen variance under burst load. Those traces are not substituted for the
controlled measurements above; they provide complementary, fine-grained timing
context.

== Objectives

The benchmark aims to validate the system against the non-functional requirements
established in Chapter 3, with a specific focus on the backend session-preparation
phase. The primary objectives are to:

1. *Quantify Startup Latency Reduction*: Measure the absolute and relative reduction
  in session preparation time achieved by the eager startup pipeline compared to the
  lazy baseline.
2. *Analyze Behavior Under Burst Concurrency*: Assess the system's robustness and
  latency degradation when subjected to a sudden spike in concurrent session
  requests.
3. *Measure Control Plane and Routing Improvements*: Isolate the performance gains
  attributed to the internal optimization of startup paths, the hardened concurrency
  handling, and the migration from `ingress-nginx` to Gateway API by comparing the
  "Lazy before optimization" and "Lazy after optimization" states.

== Results

The benchmark results demonstrate a substantial reduction in session startup latency
across both sequential and concurrent workloads.

=== Sequential Workload Results

@fig:latency-seq illustrates the latency distribution for the 100 sequential session
starts across the three system states.

#figure(
  image("../figures/benchmarks/latency_seq.svg", width: 80%),
  caption: [Session startup latency distribution for 100 sequential starts. The eager
    startup pipeline significantly reduces both the median latency and the variance
    compared to the lazy approaches.],
) <fig:latency-seq>

The baseline *Lazy before optimization* state exhibited a median startup duration of
5.59 seconds (mean: 6.40s, max: 12.35s). By introducing internal startup path
optimizations and updating the routing layer to Gateway API (*Lazy after
optimization*), the median latency improved to 4.18 seconds (mean: 4.24s, max:
8.35s).

The fastest startup time is seen in the *Eager* state. Utilizing the prewarmed pool
reduced the median startup time to just 1.37 seconds (mean: 1.54s, max: 3.28s). This
represents a 75% reduction in median latency compared to the original baseline, and a
67% reduction compared to the optimized lazy path.

=== Concurrent Workload Results

The benefits of the eager startup architecture are more pronounced under burst
conditions, as shown in @fig:latency-concurrent.

#figure(
  image("../figures/benchmarks/latency_concurrent.svg", width: 80%),
  caption: [Session startup latency distribution for 50 concurrent starts within a
    20-second window. The eager startup pipeline maintains low latency and prevents
    the severe degradation seen in the lazy provisioning paths.],
) <fig:latency-concurrent>

In the *Lazy before optimization* baseline, 50 concurrent requests caused severe
resource contention, driving the median startup time up to 18.67 seconds (mean:
20.63s), with the slowest session taking 36.31 seconds to become reachable. The *Lazy
after optimization* state handled the concurrency better due to the hardened control
plane, reducing the median to 11.58 seconds (mean: 13.13s, max: 23.72s).

The *Eager* state counteracted the burst penalty. By reserving already-running
instances rather than scheduling new pods, the median startup time remained low at
1.99 seconds (mean: 3.73s, max: 9.33s). Compared to the original baseline, this is an
89% reduction in median latency during high-stress scenarios.

== Discussion

The benchmark results confirm that the architectural changes successfully address the
primary challenges of cloud IDE provisioning in educational contexts.

The transition from on-demand provisioning to prewarming is the dominant factor in
latency reduction. By removing pod scheduling and container initialization from the
critical path, the backend preparation time drops noticeably.

The comparison between *Lazy before optimization* and *Lazy after optimization*
isolates the impact of the underlying control plane and routing enhancements. The
data shows that the previous setup was a significant bottleneck, particularly under
load. The internal optimization of startup paths, combined with the migration to
Gateway API, improved the baseline lazy startup by over a second. Furthermore, these
routing improvements provide the necessary speed for route propagation to make eager
startup viable, as the fast container assignment of the eager pool would have
otherwise been masked by slow network updates.

The concurrent workload results highlight the operational value of the hardened
control plane. In the baseline system, burst requests caused severe latency
degradation. The *Lazy after optimization* state already demonstrates significant
resilience. Building on this, the *Eager* state's synchronized reservation mechanism
ensured that the system remained stable and responsive, neutralizing much of the
burst penalty.

While the eager startup pipeline improves user experience, it introduces a tradeoff
regarding resource consumption. Maintaining a pool of prewarmed instances requires
continuous memory and CPU allocation, even when no students are active. This
emphasizes the importance of the newly introduced Scaling API. By exposing
`minInstances` and `maxInstances`, the system provides the necessary control surface
for administrators or future predictive algorithms to dynamically adjust the pool
size. This allows institutions to balance the cost of idle infrastructure against the
need for fast session availability, scaling up just before a scheduled lab and
scaling down during off-hours.

In conclusion, the implemented architecture successfully transforms prewarming from a
static infrastructure concept into a production-ready, personalized session-start
pipeline, providing a responsive and robust foundation for educational cloud IDEs.
