= Benchmark

This chapter benchmarks the implemented system architecture to determine the
effectiveness of the eager session startup pipeline and optimizations in the lazy
pipeline. It details the benchmark design, outlines the specific objectives, presents
the quantitative results, and discusses the implications of these findings for
educational cloud IDE deployments.

== Design

This benchmark systematically compares the performance of the proposed architecture
against the previous implementation state.

=== Benchmark Environment and Workloads

The benchmark suite ran against a dedicated Kubernetes cluster running the Theia
Cloud infrastructure. The cluster was provisioned as a Rancher-managed RKE2
deployment consisting of eleven QEMU virtual machines running Ubuntu 20.04.5 LTS,
organized into three control-plane nodes and eight worker nodes. Each node was
allocated 12 virtual CPUs and approximately 31.3 GiB of RAM, yielding a total cluster
capacity of 132 vCPUs and roughly 345 GiB of RAM, with the worker pool alone
contributing 96 vCPUs and 251 GiB of RAM to schedulable workloads. The underlying
physical hardware is slightly heterogeneous: the majority of nodes are backed by AMD
EPYC 9374F processors, while one control-plane node and one worker node utilize Intel
Xeon Gold 6234 processors. Networking was provided by Calico as the Container Network
Interface.

The evaluation defined two distinct workload scenarios to simulate realistic usage
patterns:

1. _Sequential Workload_: 100 session starts triggered sequentially with a 10-second
  delay between each request. This scenario represents a steady, predictable flow of
  students starting their exercises, allowing the measurement of baseline system
  latency without interference from resource contention.
2. _Concurrent Workload (Burst)_: 50 session starts distributed randomly within a
  20-second window. This scenario simulates a burst event, such as the beginning of
  an exam or a synchronized lab session, testing the control plane's ability to
  handle high concurrency and shared resource contention.

=== Baseline and Comparison Setup

For each workload scenario, the evaluation benchmarked the system in three different
states to isolate the impact of specific architectural changes:

- _Lazy before optimization (Baseline)_: The previous system state using lazy startup
  and `ingress-nginx` for routing.
- _Lazy after optimization_: The current system state using lazy startup, but
  benefiting from the Gateway API routing layer and concurrency-hardened control
  plane. In addition, the implementation introduced numerous small optimizations
  throughout the pipeline.
- _Eager_: The optimized target state using the eager session startup pipeline
  alongside the Gateway API routing layer.

=== Measurement Boundary

This benchmark measures end-to-end session-preparation time.

The timer starts with the initial API call to the Theia Cloud service that requests a
session. The timer stops when the system has fully prepared the session, scheduled
the runtime data injection, propagated the routing rules, and exposed an externally
reachable session URL. This measurement boundary corresponds directly to low startup
latency (#link(<nfr1>)[NFR1]).

This measurement does not include the client-side browser loading time. The time
taken for the student's browser to download the IDE assets, render the DOM, and
execute the frontend JavaScript is outside the optimization scope of this thesis and
is therefore excluded from the reported durations.

During development and analysis, Sentry performance data from the Theia Cloud landing
page, service, and operator helped interpret benchmark outcomes, for example to
confirm which sub-steps dominate latency or widen variance under burst load. Those
traces do not substitute for the controlled measurements above, but they provide
complementary, fine-grained timing context.

== Objectives

The benchmark aims to validate the system against the non-functional requirements
established in Chapter 3, with a specific focus on the backend session-preparation
phase. In particular, it evaluates low startup latency (#link(<nfr1>)[NFR1]),
correctness under concurrency (#link(<nfr2>)[NFR2]), scalability under burst load
(#link(<nfr3>)[NFR3]), and the diagnostic support promised by observability (#link(
  <nfr6>,
)[NFR6]). The primary objectives are to:

1. Quantify the absolute and relative reduction in session preparation time that the
  eager startup pipeline achieves compared to the lazy baseline.
2. Assess the system's robustness and latency degradation when it faces a sudden
  spike in concurrent session requests.

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

The lazy before optimization baseline exhibited a median startup duration of 5.59
seconds (mean: 6.40s, max: 12.35s). Internal startup path optimizations and the
routing layer update to Gateway API (lazy after optimization) improved the median
latency to 4.18 seconds (mean: 4.24s, max: 8.35s).

The eager state yields the lowest startup time. The prewarmed pool reduced the median
startup time to 1.37 seconds (mean: 1.54s, max: 3.28s). This represents a 75%
reduction in median latency compared to the original baseline, and a 67% reduction
compared to the optimized lazy path, providing evidence that the implementation
satisfies the low-startup-latency target (#link(
  <nfr1>,
)[NFR1]).

=== Concurrent Workload Results

Figure @fig:latency-concurrent shows that the benefits of the eager startup
architecture become more pronounced under burst conditions.

#figure(
  image("../figures/benchmarks/latency_concurrent.svg", width: 80%),
  caption: [Session startup latency distribution for 50 concurrent starts within a
    20-second window. The eager startup pipeline maintains low latency and prevents
    the severe degradation seen in the lazy provisioning paths.],
) <fig:latency-concurrent>

In the lazy before optimization baseline, 50 concurrent requests caused resource
contention, driving the median startup time up to 18.67 seconds (mean: 20.63s), with
the slowest session taking 36.31 seconds to become reachable. The lazy after
optimization state handled the concurrency better due to the hardened control plane,
reducing the median to 11.58 seconds (mean: 13.13s, max: 23.72s).

The eager state counteracted the burst penalty. Reserving already-running instances
rather than scheduling new pods kept the median startup time at 1.99 seconds (mean:
3.73s, max: 9.33s). Compared to the original baseline, this is an 89% reduction in
median latency during high-stress scenarios, while also validating the concurrency
and burst-load expectations of safe concurrency handling (#link(
  <fr6>,
)[FR6]), correctness under concurrency (#link(<nfr2>)[NFR2]), and scalability under
burst load (#link(<nfr3>)[NFR3]).

== Discussion

The benchmark results confirm that the architectural changes address the primary
challenges of cloud IDE provisioning in educational contexts.
The transition from on-demand provisioning to prewarming is the dominant factor in
latency reduction. Removing pod scheduling and container initialization from the
critical path reduces session preparation time.

Commercial cloud IDEs employ a similar pattern of shifting setup work off the
critical path. GitHub Codespaces and Gitpod use prebuilds to prepare dependencies and
configurations ahead of session creation, but those prebuilds also incur storage and
compute costs#footnote[
  GitHub, _About GitHub Codespaces prebuilds_, documentation page, accessed April 6,
  2026, #link(
    "https://docs.github.com/en/codespaces/prebuilding-your-codespaces/about-github-codespaces-prebuilds",
  )[
    docs.github.com
  ]; Gitpod, _Prebuilds_, classic documentation page, accessed April 6, 2026, #link(
    "https://ona.com/docs/classic/user/configure/repositories/prebuilds",
  )[
    ona.com/docs/classic/user/configure/repositories/prebuilds
  ].
]. The architecture in this thesis differs by emphasizing late-binding of sensitive
user context. Pooled pods remain generic until assignment and receive
session-specific data through runtime injection within a Kubernetes-native control
plane. This preserves multi-tenant isolation for educational platforms. If the pool
runs empty, the system falls back to lazy provisioning (#link(<fr7>)[FR7]). This
mirrors the cost-performance tradeoff of maintaining warm capacity discussed below
@vahidinia:2023:MitigatingColdStart.

The comparison between the lazy before optimization and lazy after optimization
states isolates the impact of the underlying control plane and routing enhancements.
The data shows that the previous setup was a significant bottleneck, particularly
under load. The internal optimization of startup paths, combined with the migration
to Gateway API, improved the baseline lazy startup by over a second. These routing
improvements provide the necessary speed for route propagation to make eager startup
viable, as slow network updates would otherwise have masked the fast container
assignment of the eager pool.

The concurrent workload results highlight the operational value of the hardened
control plane. In the baseline system, burst requests caused notable latency
degradation. The lazy after optimization state already demonstrates resilience.
Building on this, the eager state's synchronized reservation mechanism ensured that
the system remained stable and responsive, neutralizing much of the burst penalty.
When eager capacity runs out, the system can still degrade gracefully through the
availability guarantee defined by fallback to lazy startup (#link(
  <fr7>,
)[FR7]), which is the practical counterpart to scalability under burst load (#link(
  <nfr3>,
)[NFR3]).

While the eager startup pipeline improves user experience, it introduces a tradeoff
regarding resource consumption. Serverless systems demonstrate a similar pattern:
reducing cold-start latency via warm pools shifts cost from latency to continuously
allocated memory and compute, creating a cost-performance tradeoff
@vahidinia:2023:MitigatingColdStart. Measurements of prewarmed instances in the idle
state quantify this overhead. Each pod in the prewarmed state consumes 0.0006 CPU
cores and 265 MiB of memory on average, while the Kubernetes configuration reserves
200m CPU and 500 MiB memory with limits of 2 CPU and 2400 MiB. The idle footprint
therefore stays below the reserved resources, meaning the reservations dominate the
practical cost of a warm pool rather than real utilization. This emphasizes the
importance of the newly introduced Scaling API. By exposing `minInstances` and
`maxInstances`, the system provides the necessary control surface for administrators
or future predictive algorithms to dynamically adjust the pool size, exercising
programmatic scaling (#link(
  <fr5>,
)[FR5]) while keeping the maintenance of prewarmed pools (#link(
  <fr1>,
)[FR1]) economically viable. This allows institutions to balance the cost of idle
infrastructure against the need for fast session availability, scaling up just before
a scheduled lab and scaling down during off-hours.

The implemented system transforms prewarming into a production-ready, personalized
session-start pipeline, providing a responsive and robust foundation for educational
cloud IDEs that fulfills the maintenance of prewarmed pools (#link(<fr1>)[FR1]),
runtime data injection (#link(<fr3>)[FR3]), and low startup latency (#link(
  <nfr1>,
)[NFR1]) in practice.
