= Introduction

The landscape of computer science education has transformed over the past decade.
Krusche et al. note that the surge in student numbers has rendered manual assessment
of programming exercises impractical, prompting the need for automated assessment
systems @krusche:2018:ArtemisAutomaticAssessment. In response, platforms like Artemis
have emerged to provide automatic programming exercise assessment with quick feedback
at scale @krusche:2018:ArtemisAutomaticAssessment.

Online IDE services for training, assessments, and development environments have
proliferated as learning platforms increasingly migrate their development
infrastructure to the cloud @srinivasa:2022:BadIDEaWeaponizing
@usa:2024:CloudBasedLightweightModern. These cloud-hosted environments eliminate
local setup requirements and provide consistent, standardized development experiences
to students @schmidt:2024:InclusiveLearningEnvironmentsa.

Eclipse Theia is an extensible cloud and desktop IDE platform. It provides a unified
interface for various programming languages in a browser-based environment. Theia
Cloud enables the deployment and management of Theia-based IDEs on Kubernetes at
scale. Artemis integrates Theia as shown in @fig:ssd.

#figure(
  image("../../figures/ssd3.svg"),
  caption: [The deployment diagram showing the integration between Artemis and Theia
    Cloud. Adapted from Schmidt @schmidt:2024:InclusiveLearningEnvironmentsa.],
) <fig:ssd>


// Ideally, the integration with a learning platform enables students to launch
// pre-configured development environments from their course assignments without any
// local installation, receiving timely automated feedback.
