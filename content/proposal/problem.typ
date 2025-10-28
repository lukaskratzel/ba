= Problem

Despite the benefits of cloud-based IDEs like Theia Cloud, critical issues around
performance, user experience, and infrastructure scalability impede their practical
use in educational settings.

One core problem is rooted in startup delays. When a student starts a session, the
system provisions a Kubernetes pod to host the development session. This process can
exceed 30 seconds, depending on system load and resource availability, creating
delays during assignment releases or approaching deadlines.

Binding users to prewarmed environments also presents a significant challenge to
system administrators. To address startup latency, Theia Cloud maintains pools of
prewarmed containers, an approach validated by Mohan et al.
@mohanAgileColdStarts2019. However, prewarmed environments are generic, while each
student requires personalized configurations like version control credentials and
assignment metadata. Technically, this personalization poses a significant challenge.
