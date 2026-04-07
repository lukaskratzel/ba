= Summary

This final chapter reviews the status of the project by contrasting the realized
goals with those that remain open. Following this, a conclusion is drawn on the
overall impact of the implemented architecture. Finally, potential avenues for future
work are discussed, outlining how the system can be further extended and optimized.

== Status

The primary objective of this thesis was to design and implement an architectural
foundation for low-latency, personalized cloud IDE sessions in educational
environments, specifically within the context of Theia Cloud and Artemis.

=== Realized Goals

The implementation successfully achieved the core objectives set out at the beginning
of the project. First, a robust eager session start mechanism was implemented.
Generic IDE instances are prewarmed and allow for rapid, synchronized reservation,
which realizes the maintenance of prewarmed pools (#link(<fr1>)[FR1]) and dynamic
session assignment (#link(<fr2>)[FR2]) while significantly reducing provisioning
delays in line with low startup latency (#link(<nfr1>)[NFR1]). Second, the
contradiction between generic prewarming and user-specific environments was resolved
through runtime personalization. The introduction of the `theia-data-bridge` and the
adaptation of the Scorpio extension enabled secure injection of credentials into
already-running containers, thereby fulfilling runtime data injection (#link(
  <fr3>,
)[FR3]), support for Artemis workflows (#link(<fr4>)[FR4]), and security and
isolation (#link(<nfr4>)[NFR4]). Third, the control plane was fortified to handle
burst workloads. Mechanisms such as race-aware session handling, synchronized pool
reservations, and independent route mutations ensure the system remains stable during
simulated load scenarios. Fourth, the migration from `ingress-nginx` to the
Kubernetes Gateway API significantly reduced routing propagation delays, unblocking
the latency benefits of the prewarmed pool. Fifth, a dedicated Scaling API was
implemented to expose and control the `minInstances` and `maxInstances` parameters,
successfully decoupling the mechanical scaling of the infrastructure from the logic
of demand prediction. Sixth, detailed instrumentation was integrated into the Theia
Cloud landing page, service, and operator. By adding Sentry transactions and spans
over session-start operations across all major system components, timing and failures
can be diagnosed at the level of pool reservation, routing updates, and data
injection. This facilitates both iterative optimization and operational monitoring.
Taken together, these changes satisfy programmatic scaling (#link(<fr5>)[FR5]), safe
concurrency handling (#link(<fr6>)[FR6]), fallback to lazy startup (#link(
  <fr7>,
)[FR7]), correctness under concurrency (#link(<nfr2>)[NFR2]), scalability under burst
load (#link(<nfr3>)[NFR3]), and observability (#link(<nfr6>)[NFR6]).

=== Open Goals

While the foundational architecture is complete, certain aspects of the original
vision remain open. These are objectives that were part of the initial scope but
require further refinement or validation.

First, while the benchmarks were conducted in a controlled and simulated environment,
a broader evaluation using real student traffic during an active semester is
necessary to fully validate the system's impact on user experience and infrastructure
load. Second, while the current concurrency measures prevent system failure during
bursts, extreme scenarios involving hundreds of simultaneous requests can still
bottleneck at synchronization points in the operator. Fully resolving these
bottlenecks to maximize throughput remains an open objective for the upper limits of
scalability under burst load (#link(<nfr3>)[NFR3]).

== Conclusion

This thesis successfully implemented the architectural basis for low-latency,
personalized cloud IDE sessions in educational environments. By transitioning Theia
Cloud from a purely lazy provisioning model to a production-oriented eager startup
pipeline, the backend session-preparation time was reduced by up to 89% under burst
loads, thereby meeting the central target of low startup latency (#link(
  <nfr1>,
)[NFR1]).

The core contribution lies in proving that prewarming can be practically applied to
highly personalized educational tools. By combining prewarmed instance pools,
concurrency-safe control planes, faster Gateway API routing, runtime data injection,
and Sentry-backed observability on the landing page, service, and operator, the
system delivers fast access to fully configured development environments and remains
analyzable when latency or load patterns shift. Furthermore, the introduction of the
Scaling API ensures that this architecture is not a static solution but a prepared
foundation ready to integrate with future predictive scaling systems. Ultimately,
this work significantly enhances the usability of cloud IDEs for students while
providing administrators with the robust infrastructure needed to support
large-scale, synchronous educational activities. In requirement terms, the resulting
architecture demonstrates the maintenance of prewarmed pools (#link(<fr1>)[FR1]),
runtime data injection (#link(<fr3>)[FR3]), programmatic scaling (#link(<fr5>)[FR5]),
correctness under concurrency (#link(<nfr2>)[NFR2]), security and isolation (#link(
  <nfr4>,
)[NFR4]), and observability (#link(<nfr6>)[NFR6]) in a cohesive production setting.

== Future Work

The completed architecture opens several promising directions for future research and
engineering that extend beyond the scope of this thesis.

With the Scaling API in place, the immediate next step is the development of a
predictive scaling service. By consuming historical usage data such as exercise
release schedules and typical student working hours, this service could proactively
adjust the prewarmed pool just before demand spikes, minimizing both latency and the
cost of idle resources.

As the server-side session preparation time has been significantly reduced, the
client-side latency bottleneck is now a relevant contributor to the overall startup
latency. Optimizing the browser's loading of the IDE session, asset caching, and
initial rendering is the next logical step toward improving the end-to-end startup
experience.

While Sentry currently covers server-side session-start paths, extending this
telemetry into the student-facing IDE would close the observability gap. Implementing
client-side tracing would capture the true perceived latency and help pinpoint
rendering or network bottlenecks in the browser.


Suggested New Claim / Detail,Section to Add,Benefit to Thesis "Response Time
Thresholds: Define ""low latency"" using established human-computer interaction (HCI)
limits (e.g., the 2-second rule).",3.2.2 Nonfunctional Requirements,"Instead of just
saying ""significantly reduced"" , you can argue your 1.37s result meets specific
pedagogical/psychological requirements for student focus.+1" "Comparison to ""State
of the Art"" Cloud IDEs: Add a brief comparison to how commercial tools (e.g., GitHub
Codespaces or Gitpod) handle prewarming.",5.4 Discussion,"It puts your work in
context with industry leaders, showing that your solution for educational platforms
is on par with professional-grade infrastructure.+1"
