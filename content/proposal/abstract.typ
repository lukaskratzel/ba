= Abstract

Online IDEs reduce technical barriers in computer science education by providing immediate access to
programming tools without complex local installations. However, Eclipse Theia Cloud suffers from
slow startup times due to Kubernetes resource provisioning delays, with cold starts exceeding 60-90
seconds. This thesis designs and implements a comprehensive scaling API and prewarming system that
builds upon Theia Cloud's existing provisioning mechanisms. The solution provides a unified API that
enables scaling through dynamic session pool management, secure user-to-container binding, and
demand-based provisioning strategies. By extending Theia Cloud's architecture with a dedicated
prewarming service, the system maintains ready-to-use IDE containers while ensuring secure session
handling and efficient resource utilization.
