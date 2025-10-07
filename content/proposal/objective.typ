= Objective

This thesis aims to design, implement, and evaluate a comprehensive solution for predictive scaling and container prewarming in cloud-based IDE deployments for educational platforms. The work will address the identified challenges through four primary objectives:

1. Develop a predictive autoscaling strategy for Theia Cloud on Kubernetes
2. Implement a container prewarming mechanism to eliminate cold-start delays
3. Design an integrated architecture for Artemis-Theia Cloud with secure user binding
4. Evaluate system performance and impact on student experience

#include "/figures/sequence_diagram.typ"

Figure 2 illustrates the complete workflow from demand prediction through session binding, showing how predictive provisioning eliminates wait times for students.

== Develop a Predictive Autoscaling Strategy for Theia Cloud on Kubernetes

This objective focuses on creating a demand forecasting system that anticipates IDE usage patterns and proactively adjusts resource allocation. Building on research by @rubakMachineLearningPredictive2023a, which demonstrated that multiple machine learning models can accurately forecast resource requirements with "high precision and performance," the implementation will leverage historical session data, course schedules from Artemis, and real-time usage signals. The forecasting component will analyze patterns such as weekly class schedules, assignment deadlines, and historical launch rates per programming language and course to generate demand predictions over a 15-60 minute lookahead horizon.

The predictive strategy will extend Theia Cloud's existing Kubernetes operator to dynamically adjust the `minInstances` parameter in `AppDefinition` custom resources based on forecast output. This approach reuses the platform's native reconciliation mechanisms while adding intelligence to scale decisions. The system will incorporate confidence-based safety margins to meet service level objectives and implement rate-limiting to prevent oscillation. By shifting from reactive to predictive provisioning, this objective aims to ensure sufficient warm containers are available before demand spikes occur, rather than scrambling to provision resources after users have already experienced delays.

== Implement a Container Prewarming Mechanism to Eliminate Cold-Start Delays

This objective addresses the technical challenge of maintaining a pool of ready-to-use Theia IDE containers that can be instantly assigned to users. Following the approach validated by @mohanAgileColdStarts2019, the implementation will maintain pre-initialized containers with all dependencies loaded, effectively reducing startup time to near-zero by eliminating image pull, container creation, and application initialization delays. The prewarming mechanism will work in conjunction with the predictive scaling strategy to ensure the warm pool size matches anticipated demand.

The implementation will build upon Theia Cloud's existing eager provisioning handlers, extending the `EagerStartAppDefinitionAddedHandler` to support dynamic pool scaling both up and down. Special attention will be paid to security considerations in the prewarming architecture: pre-created containers must remain isolated and unprivileged until they are bound to authenticated users. The binding process, handled by the `EagerSessionHandler`, will be hardened to ensure that OAuth2 proxy configurations and ingress rules are fully propagated before session URLs are exposed to users. This prevents race conditions and ensures that prewarmed containers cannot be accessed by unauthorized users, maintaining the security properties of the current on-demand provisioning model while achieving dramatically lower latency.

== Design an Integrated Architecture for Artemis-Theia Cloud with Secure User Binding

This objective encompasses the architectural integration between Artemis and Theia Cloud, ensuring that the predictive scaling and prewarming capabilities work seamlessly within the existing educational platform. The design will specify how Artemis course schedules, assignment metadata, and real-time user activity feed into the demand forecasting system. It will also define webhook endpoints and API extensions that allow Artemis to signal high-priority events like assignment releases that should trigger immediate warm pool expansion.

Beyond the forecasting integration, this objective addresses the end-to-end user experience and security model. The architecture must ensure that when a student clicks to launch an IDE from an Artemis assignment, they are seamlessly and securely bound to a prewarmed container with appropriate resource limits, environment variables, and workspace configuration. The design will leverage Keycloak authentication, Kubernetes network policies, and OAuth2 proxy configurations to maintain multi-tenant isolation. Additionally, the architecture will incorporate session lifecycle management, including idle timeout mechanisms and workspace persistence for courses that require stateful environments. The resulting design should be generalizable beyond Artemis to other learning management systems while being thoroughly validated in the Artemis deployment context.

== Evaluate System Performance and Impact on Student Experience

This objective focuses on comprehensive evaluation of the implemented solution across technical performance metrics and user experience dimensions. The evaluation will measure concrete improvements in session startup latency, comparing cold starts versus warm container assignment under various load conditions. Using the existing Theia scale test infrastructure with Playwright-based scenarios, the thesis will simulate realistic educational usage patterns including synchronized launches of 100+ concurrent sessions. Key metrics include P50, P95, and P99 startup times, prewarm utilization rates (percentage of sessions served from the warm pool), forecast accuracy, and resource efficiency (cost per active session-hour compared to baseline reactive scaling).

Beyond technical metrics, the evaluation will assess the impact on the learning experience through qualitative feedback and adoption patterns. If possible within the thesis timeline and with appropriate ethical approvals, the evaluation will gather student perceptions through surveys or focus groups, examining whether reduced startup times correlate with increased engagement and satisfaction. The methodology will draw from prior work such as @benottiEffectWebbasedCoding2018, which used student surveys and learning outcome metrics to assess the impact of improved coding tools. The evaluation will also analyze system behavior during real-world educational events—such as the start of a semester or a major assignment deadline—to validate that the predictive approach handles actual burst scenarios more effectively than reactive scaling. Success will be defined as achieving 80-95% reduction in P95 startup latency while maintaining or reducing infrastructure costs compared to static over-provisioning approaches.
