= Abstract

Online IDEs reduce technical barriers in computer science education by providing
immediate access to programming tools without complex local installations. However,
deploying such systems at scale introduces performance challenges. Eclipse Theia
Cloud suffers from slow startup times due to Kubernetes resource provisioning delays,
with cold starts exceeding 30 seconds. This thesis designs and implements a scaling
API and prewarming system that builds upon Theia Cloud's existing provisioning
mechanisms. The solution provides a unified API that enables scaling through dynamic
session pool management and secure user-to-container binding. The system pre-creates
pools of generic IDE containers and injects user-specific credentials, workspace
settings, and routing configurations when students launch sessions, reducing startup
latency while maintaining security isolation.
