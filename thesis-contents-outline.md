# Thesis Contents Outline

This document is a working draft for the thesis structure. It follows the chair's template closely, but adapts the contents to the actual thesis topic and implementation results:

- low-latency Theia Cloud session startup,
- eager prewarming,
- runtime personalization of prewarmed sessions,
- concurrency handling for burst scenarios such as exams,
- routing improvements through Gateway API and Envoy Gateway,
- and the scaling API as groundwork for future predictive scaling.

## Proposed Thesis Structure

## 1 Introduction

### 1.1 Problem

Focus:

- startup latency of cloud IDE sessions in educational settings
- limitations of purely lazy session startup
- difficulty of combining prewarming with personalization
- additional stress caused by burst scenarios such as exercise releases and exams
- clear definition of the optimization scope: the backend session-preparation path from the landing page's API call to Theia Cloud until the session URL is prepared
- explicit exclusion of the browser-side latency from opening the session URL until the IDE is fully loaded and usable
 
Heavily based on proposal

### 1.2 Motivation

Focus:

- importance of responsive IDE startup for student workflows
- relevance of Theia Cloud and Artemis in programming education
- practical need for personalized but fast online IDE sessions
- operational need for robustness under high concurrency

Heavily based on proposal

### 1.3 Objectives

Focus:

- improve session startup latency through eager prewarming
- enable runtime personalization of prewarmed sessions
- improve high-concurrency behavior during burst session starts
- reduce routing-related startup delays
- provide a scaling interface as a basis for future predictive scaling
- evaluate the optimized startup segment with a clearly defined measurement boundary

Based on proposal

### 1.4 Outline

Briefly describe the rest of the thesis chapter by chapter.

## 2 Related Work

### 2.1 Cloud IDEs in Education

Include refs on startup latency

### 2.2 Prewarming and Cold-Start Mitigation

<!-- ### 2.3 Session Personalization in Preprovisioned Environments -->
<!-- ### 2.4 Elastic and Predictive Scaling for Interactive Systems -->

Focus:

- prior work on cloud IDEs and prewarming
- similar systems where relevant
- differences between prior work and the implemented system

## 3 Requirements

Introduce the requirements chapter and separate existing system, target system, and models.
Provide the technical explanation needed to understand the existing system, the target system, and the resulting requirements.

### 3.1 Existing System

#### 3.1.1 Theia Cloud Session Startup

Focus:

- what Theia Cloud is in the scope of this thesis
- how sessions are provisioned in principle
- relevant concepts such as `AppDefinition` and `Session`
- original lazy session startup path
- prior eager/prewarming limitations if relevant

#### 3.1.2 Artemis-Theia Integration

Focus:

- Artemis as the surrounding educational platform
- role of programming exercises
- why IDE startup and repository access matter in this context
- previous Scorpio / Artemis integration assumptions
- problems in the Theia environment

#### 3.1.3 Deployment and Routing

Focus:

- Kubernetes concepts only as needed for the existing setup:
  - deployments
  - services
  - config maps and secrets
  - controllers/operators
  - shared routing resources
- why routing matters for startup time
- core idea of `HTTPRoute`
- previous ingress-nginx-based setup
- why Envoy Gateway became relevant in this implementation
- routing propagation as part of startup delay

#### 3.1.4 Personalization and Prewarming Constraints

Focus (short chapter):

- idea of prewarming and why cold starts are problematic
- tradeoff between latency and resource usage
- why prewarmed sessions cannot be personalized at creation time
- why runtime injection is needed
- security and isolation considerations

### 3.2 Proposed System

#### 3.2.1 Functional Requirements

Candidate requirements:

- maintain prewarmed pools per `AppDefinition`
- assign warm sessions dynamically to users
- inject session-specific runtime data after assignment
- support Artemis workflows inside Theia
- expose scaling parameters through an API
- handle concurrency safely under burst load
- support fallback when eager capacity is exhausted

#### 3.2.2 Nonfunctional Requirements

Candidate quality attributes:

- low startup latency
- correctness under concurrency
- scalability under burst load
- maintainability
- security and isolation
- observability

Measurement boundary note:

- the main latency attribute considered in this thesis is the backend preparation time from the landing page request to the point where the session URL is ready
- the latency of loading the IDE in the browser after opening that URL is outside the optimization scope of this thesis and usually lies in the ~2 sec range

### 3.3 Dynamic Models

Candidate dynamic views:

- eager session start
- eager pool exhausted with fallback to lazy startup
- burst exam-start scenario with contention points
- runtime credential injection after session assignment
- scaling parameter adjustment by an admin or external service

## 4 Architecture

### 4.1 Design Goals

Candidate design goals:

- reduce startup latency
- personalize prewarmed sessions safely
- remain robust under burst load
- preserve compatibility with the existing platform
- prepare for future predictive scaling

### 4.2 Subsystem Decomposition

Candidate subsections:

- Big SSD diagram
- Component diagram
- Class diagram if really implementation oriented

<!-- #### 4.3.1 Eager Session Start in Theia Cloud
#### 4.3.2 Prewarmed Resource Pool Management
#### 4.3.3 Routing through Gateway API and Envoy Gateway
#### 4.3.4 Runtime Personalization with `theia-data-bridge`
#### 4.3.5 Scorpio Adaptation for Theia
#### 4.3.6 Scaling API -->

### 4.3 Hardware Software Mapping

Focus:

- Kubernetes cluster as deployment environment
- service and operator components
- shared route resources
- prewarmed IDE deployments
- IDE runtime components inside containers

### 4.4 Persistent State and Scaling Control

Briefly explain that the system persists its operational state primarily through Kubernetes resources in the cluster, with config maps and secrets providing configuration and sensitive data where needed.

Then explain how scaling-relevant state is controlled through the configured conditions on each `AppDefinition` and adjusted through the Scaling API.

Possible focus:

- Kubernetes resources as persisted system state
- config maps and secrets as configuration sources
- `minInstances` controls eager prewarmed pool size
- `maxInstances` controls the total number of sessions for an `AppDefinition`
- any capacity above `minInstances` is always handled via lazy startup
- Scaling API as the interface used to inspect and update scaling-related state
- secret storage used in the IDE runtime if relevant

## 5 Benchmark

### 5.1 Design

Focus:

- evaluation environment
- workloads and scenarios
- baseline and comparison setup
- exact measurement boundary of the evaluated startup path

Important clarification to include:

- the measured and optimized path starts with the landing page's API call to the Theia Cloud service
- it ends when the session has been prepared and the session URL is available / reachable according to the chosen measurement definition
- it does not include the browser-side loading time from opening that URL until the online IDE is fully rendered and usable

### 5.2 Objectives

Candidate evaluation objectives:

- quantify startup latency reduction
- analyze behavior under burst concurrency
- measure the routing improvement after migration to Gateway API / Envoy Gateway
- validate correctness of runtime personalization

Clarify that these objectives apply to the backend session-preparation portion of startup, not to client-side IDE rendering latency.

### 5.3 Results

Possible result categories:

- cold vs eager startup latency
- burst-start throughput and latency
- route propagation observations
- personalization overhead

Results should explicitly state the measured interval so readers do not interpret them as full end-to-end time-to-usable-IDE measurements.

### 5.4 Discussion

Focus:

- interpretation of the results
- most important effects
- key bottlenecks before and after the changes
- operationally relevant observations
- tradeoffs between low latency and resource consumption
- practical implications for educational use

## 6 Summary

### 6.1 Status

#### 6.1.1 Realized Goals

Candidate points:

- eager session start
- runtime personalization
- concurrency hardening for burst scenarios
- Gateway API / Envoy Gateway migration
- scaling API

#### 6.1.2 Open Goals

Candidate points:

- predictive scaling logic
- more automated tuning of pool sizes
- increased throughput
- broader or longer-term evaluation

### 6.2 Conclusion

Summarize the final contribution of the thesis as an architectural basis for low-latency personalized cloud IDE sessions in educational settings.

### 6.3 Future Work

Candidate directions:

- predictive scaling based on forecasts
- further optimization of burst handling
