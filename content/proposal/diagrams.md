

# After introduction

Show the current THEIA architecture as a deployment diagram

- Artemis Cluster
    - Artemis
    - Programming Exercise
- Theia Cluster
    - Theia Operator
    - Landing Page
    - Theia IDE Session
- Keycloak Authentication Service

# After motivation

Activity diagram showing the desired flow between Student and Theia Operator.

- Student starts exercise
- Theia cloud authenticates student
- Checks for prewarmed container
- Decision: Container found?
- Yes: Load preconfigured workspace and exercise information
- No: Provision new container
- Start theia, language server, etc.
- Student: Work on exercise
- Submit exercise
