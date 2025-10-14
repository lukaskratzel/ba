***
![A blue, stylized representation of the letters TUM, forming a blocky, abstract logo.](https://storage.googleapis.com/assist-v2-public/images/84100c82110c14b77f98826727284f22.png)
***
**Image Description:** The image shows the logo of the Technical University of Munich (TUM). It consists of three stylized, bold, blue letters: "T", "U", and "M". The letters are arranged in a block-like, abstract manner.
***

Technical University of Munich

School of Computation, Information and Technology  
-- Informatics --

Master's Thesis in Computer Science

# Theia Prewarming and Predictive Scaling
## Theia Prewarming und Vorhersagbare Skalierung

**Author:**
Darius Augsburger

**Supervisor:**
Prof. Dr. Stephan Krusche

**Advisors:**
Matthias Linhuber, M.Sc.

**Start Date:**
13.08.2025

**Submission Date:**
01.03.2026

---

## Abstract
Cloud-based IDEs like Theia Cloud offer flexible, scalable development environments for students, but they suffer from startup delays when many users access them simultaneously. This thesis addresses these challenges through three main approaches: prewarming environments to reduce startup latency, enabling dynamic and secure user binding for personalized configurations, and applying machine learning to predict demand based on historical usage and course schedules. We will integrate the proposed solution into the Artemis Learning Platform and test it in real-world university courses. The goal is to improve responsiveness, scalability, and resource efficiency in educational cloud IDE deployments.

## 1 Introduction
Cloud-based development environments are increasingly shaping the way software is taught and developed, especially in educational institutions [Hen+21]. Artemis is such a cloud-based interactive learning platform designed to support the teaching of software engineering skills such as modeling and programming [KS18]. To enhance its practical learning components, Artemis integrates Theia Cloud as described in Figure 1. Theia Cloud is a browser-accessible, online Integrated Development Environment (IDE) that provides users with fully provisioned, ready-to-code execution environments directly in the web browser.

This allows students to focus on writing code without the overhead of local setup and configuration [Sch24]. Platforms like Theia are often integrated into digital learning systems to support practical programming exercises during lectures and tutorials [Fra+24]. These environments usually run in containerized infrastructures—commonly orchestrated with Docker and Kubernetes—which enable scalable and reproducible software development workspaces for large groups of users [Naw+20].

---

***
![A deployment diagram showing the interaction between Artemis Cluster, Theia Cluster, and an Authentication Service.](https://storage.googleapis.com/assist-v2-public/images/ab5b42d76378e9989601d81f2622f3e8.png)
***
**Image Description:** Figure 1 is a deployment diagram illustrating the architecture of a system that includes Artemis, Theia Cloud, and the KeyCloak Authentication Service. The diagram is divided into three main components. On the left, the "Artemis Cluster" contains "Artemis," which has a "Programming Exercise" module. This module communicates with an "Online IDE Service" and an "Exercise and Feedback Service" in the "Theia Cluster." The "Theia Cluster" is shown on the right and contains the "Online IDE Service," "Theia Landing Page," "Scorpio," and "Theia Instance." Arrows indicate the flow of communication between these components. At the top, an "Authentication Service" box contains "Keycloak," which provides authentication for both the Artemis and Theia clusters.
***

Figure 1: The deployment diagram including Artemis, Theia Cloud and the Authentication Service KeyCloak.

## 2 Problem
Despite the benefits of cloud-based IDEs like Theia Cloud, their practical use in educational settings is hindered by several critical issues—particularly around performance, user experience, and infrastructure scalability.

One core problem lies in the startup delay of tool environments. When a user initiates a session, the system provisions a dedicated Kubernetes pod to host the development workspace. This process often takes tens of seconds, or even minutes, depending on system load and resource availability [Fra+24].

Another challenge is the binding of users to prewarmed environments. To address startup latency, system administrators may attempt to keep environments “prewarmed” and ready to use. However, prewarmed environments are typically generic, while users require personalized configurations such as version control credentials, persistent storage access, and customized workspace settings.

---

On the infrastructure side, balancing resource usage with demand is an ongoing challenge. Provisioning too few environments leads to long wait times; provisioning too many leads to idle resource consumption and increased cost—particularly problematic in university or public-sector settings with limited budgets [Sch24].

## 3 Motivation
As cloud-based IDEs like Theia become central to modern computer science education [Hen+21], addressing their performance and scalability challenges becomes not only a matter of user convenience but also one of scientific and pedagogical relevance. Improving the responsiveness of the environments has the potential to enhance the learning experience for students, while also enabling more flexible and reliable digital teaching methods for educators [LBK23].

If delays during environment startup can be significantly reduced or eliminated, students can engage in hands-on coding exercises as described in Figure 2 without interruption, leading to a more immersive and productive learning environment. Instructors, in turn, can confidently plan interactive sessions that rely on immediate tool access, enriching the classroom experience [Fra+24].

Rather than relying on static over-provisioning or reactive scaling, universities can utilize data-driven forecasting to align capacity with actual demand. This aligns well with broader institutional goals of sustainability and efficiency of teaching infrastructure [HB21].

---

***![An activity diagram showing the workflow for a student starting an exercise in Theia Cloud.](https://storage.googleapis.com/assist-v2-public/images/154504100c5c7d031e5088c4b182f2f0.png)
***
**Image Description:** Figure 2 is an activity diagram that illustrates the desired workflow for a student starting an exercise. The diagram has two swimlanes: "Student" and "Theia Cloud." The process starts in the "Student" lane with the "Start exercise" action. An arrow points to the "Theia Cloud" lane, triggering the "Authenticate student in KeyCloak" action. This is followed by "Load preconfigured workspace and exercise information." The flow then moves back to the "Student" lane with the "Work on exercise" action, followed by "Submit exercise." The diagram ends with a final state symbol.
***

Figure 2: Desired activities when starting an exercise as a student. Theia Cloud authenticates the user with KeyCloak and dynamically binds user and exercise information to the assigned pod.

## 4 Objective
The main goal of this thesis is to improve the responsiveness and scalability of Theia Cloud environments used in educational settings by implementing prewarming and predictive provisioning strategies. We will achieve this with the following specific objectives:

1. Enhance Prewarming Mechanism in Theia Cloud
2. Implement Secure and Dynamic User Binding for Prewarmed Environments
3. Develop and Integrate Predictive Provisioning for Theia Cloud
4. Integrate Prewarming and Predictive Provisioning into Artemis

---

### 4.1 Enhance Prewarming Mechanism in Theia Cloud
The goal of this objective is to improve the partially existing prewarming mechanism in Theia Cloud to ensure it functions as intended. Currently, the implementation relies on an operator that statically prewarms a specified number of instances while scaling up to a maximum as needed. However, the mechanism is not working and requires refinement. To achieve this, the implementation will focus on debugging and enhancing the operator’s logic to ensure that we provision and scale prewarmed pods correctly. This includes verifying the handling of minimum and maximum instances, ensuring that the system efficiently allocates resources without over- or underprovisioning.

Additionally, we need to ensure that Theia Cloud reacts to changes in minimum and maximum instances for dynamically adjusting the number of prewarmed pods based on real-time or predicted demand.

### 4.2 Implement Secure and Dynamic User Binding for Pre-warmed Environments
Prewarmed environments are generic by default, but users require personalized settings such as Git credentials, workspace files, and editor configurations. This objective aims to implement a mechanism for injecting user-specific data into prewarmed environments at the time of login. This ensures that users can seamlessly transition into their personalized development environments without compromising security.

To achieve this, the implementation of a custom service ensuring correct session handling and user binding will be explored. Additionally, the mechanism must prevent unauthorized access to shared resources while minimizing delays in the injection process. This will require careful design to ensure both functionality and security.

---

### 4.3 Develop and Integrate Predictive Provisioning for Theia Cloud
To further optimize prewarming and scaling, this objective focuses on building a machine learning model capable of predicting future demand. The model will analyze inputs such as historical access logs, course schedules, calendar data (e.g., lecture times), and past load patterns to provide time-based provisioning recommendations.

We will test the effectiveness of the model based on prediction accuracy, reduced waiting times, and resource efficiency. By anticipating demand, the provisioning system can prepare environments proactively, reducing delays and improving the overall user experience. This objective will involve experimenting with different algorithms and testing the model against real-world data.

### 4.4 Integrate Prewarming and Predictive Provisioning into Artemis
This objective involves unifying the developed modules — prewarming and predictive scaling — into the existing Artemis platform. The integration must be robust, maintainable, and compatible with existing workflows to support real-time classroom use.

The process will include implementing interfaces, managing data flow between components, and ensuring deployment readiness for university-scale environments. Special attention will be given to ensuring the solution is scalable and adaptable, allowing it to meet the diverse needs of educational institutions while maintaining reliability.

---

## 5 Schedule
The thesis begins in August 2025 and spans approximately a duration of 29 weeks. The timeline is structured into seven iterations. Every iteration contains concrete, measurable work items that build on each other and focus on delivering functional components that are usable and testable in real-world scenarios. Writing and documentation tasks will be handled in parallel and are not included in the schedule below.

### 5.1 Iteration 1 (Weeks 1-4): Scalable Prewarmed Environment (Objective 4.1)
* Analyze the current provisioning process in Theia Cloud and Artemis.
* Adjust the current Theia Cloud implementation to allow for dynamic scaling of prewarmed pods.
* Design a modular architecture for prewarming, user binding, and predictive scaling.
* Set up a prototype environment for Kubernetes-based pod orchestration.
* Provision and validate that 100 Theia instances can be launched in parallel and clone an Artemis repository.

### 5.2 Iteration 2 (Weeks 5-8): User Binding Implementation (Objectives 4.2)
* Extend prewarmed instances to support dynamic user injection.
* Integrate Scorpio workflow (problem statement, submission, build results) into prewarmed pods.

---

### 5.3 Iteration 3 (Weeks 9-12): Develop the Prewarming Service (Objective 4.4)
* Implement a prewarming service that can control the number of prewarmed instances based on artificial demand dynamically.

### 5.4 Iteration 4 (Weeks 13-15): Setup Monitoring Infrastructure (Objective 4.3, 4.4)
* Deploy monitoring infrastructure for usage and latency metrics.
* Collect and preprocess usage data (e.g., login times, course schedules).

### 5.5 Iteration 5 (Weeks 16-20): Implement Predictive Scaling Model (Objective 4.3)
* Train and validate a demand prediction model with test data.
* Collect quantitative data (e.g. startup delays, resource usage, prediction accuracy).
* Integrate the prediction model into the prewarming service.
* Use prediction output to decide on proactive provisioning.

### 5.6 Iteration 6 (Weeks 20-24): First Real-World Tests in Courses (Objective 4.4)
* Deploy the current system version in one or more live university courses.
* Collect startup time, session stability, and basic user experience under real-world conditions.
* Collect feedback from students and instructors.
* Identify technical and usability issues and prioritize fixes.
* Document testing results to serve as a baseline for future improvements.

---

### 5.7 Iteration 7 (Weeks 25-29): Monitoring, Refinement, and Final Testing
* Conduct a second test in a production course setting if possible.
* Collect final quantitative data.
* Finalize system improvements and complete performance benchmarking.

---

## Bibliography
[Hen+21] D. Henriksson, Y. Ferm, J. Zibert, A. H. S. Chan, and J. Hallberg, “Cloud-Based Integrated Development Environments: A Review of Features, Benefits and Challenges,” Education and Information Technologies, vol. 26, no. 6, pp. 7255–7274, 2021, doi: 10.1007/s10639-021-10579-2.

[KS18] S. Krusche and A. Seitz, “ArTEMiS: An Automatic Assessment Management System for Interactive Learning,” in Proceedings of the 49th ACM Technical Symposium on Computer Science Education, Baltimore Maryland USA: ACM, Feb. 2018, pp. 284–289. doi: 10.1145/3159450.3159602.

[Sch24] Y. Schmidt, “Inclusive Learning Environments in the Cloud: Scalable Online IDEs for Higher Education,” 2024.

[Fra+24] E. Frankford, D. Crazzolara, C. Sauerwein, M. Vierhauser, and R. Breu, “Requirements for an Online Integrated Development Environment for Automated Programming Assessment Systems:,” in Proceedings of the 16th International Conference on Computer Supported Education, Angers, France: SCITEPRESS - Science, Technology Publications, 2024, pp. 305–313. doi: 10.5220/0012556400003693.

[Naw+20] S. Nawshin, S. Ahsin, M. Ali, S. Islam, and S. Shatabda, “Voice-Enabled Intelligent IDE in Cloud,” Proceedings of International Joint Conference on Computational Intelligence. Springer Singapore, Singapore, pp. 57–69, 2020. doi: 10.1007/978-981-15-3607-6_5.

[LBK23] M. Linhuber, J. P. Bernius, and S. Krusche, “Constructive Alignment in Modern Computing Education: An Open-Source Computer-Based Examination System,” in Proceedings of the 23rd Koli Calling International Conference on Computing Education Research, Koli Finland: ACM, Nov. 2023, pp. 1–11. doi: 10.1145/3631802.3631818.

---

[HB21] T. Hinrichs and H. Burau, “A Scaleable Online Programming Platform for Software Engineering Education,” 2021.

---

## Transparency in the use of AI tools
**Categories of AI Usage: Content Generation and Idea Expansion Tools:**
ChatGPT, OpenAI Codex Purpose: I used it to generate initial drafts, expand on ideas, provide suggestions for content, and offer examples.

**Coding Assistance Tools:** GitHub Copilot Purpose: I used it to help with coding tasks, generate code snippets, and provide programming solutions and explanations.