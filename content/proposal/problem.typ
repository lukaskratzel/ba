= Problem

// Feedback TODO: in general, the problem should focus more on the core difficulty:
// It's hard to personalize prewarmed environments with exercise details, credentials, etc.
// A more general rewrite could be necessary here.

Deploying cloud IDEs at educational scale introduces significant challenges. The
platform must handle synchronized usage spikes when many students simultaneously
access resources at predictable times such as course starts, lab sessions, and
assignment deadlines. The underlying Kubernetes infrastructure must provision and
initialize containers quickly enough to meet demand while managing resources
efficiently. Current reactive scaling approaches often fall short due to
infrastructure provisioning delays and container initialization times, a problem that
amplifies during synchronized usage spikes.

For *students*, the most immediate problem is startup latency when launching cloud
IDE sessions. In the context of Theia Cloud, cold starts involving infrastructure
provisioning, container initialization, Theia boot, and language server startup can
exceed 30 seconds. During assignment releases or approaching deadlines, students face
frustrating delays when they are most motivated to begin work.
// TODO: should be shorter
Rubak and Taheri demonstrate that Kubernetes' default Horizontal Pod Autoscaler "is
not always able to scale up in time to catch up with load bursts," meaning sudden
surges of users can overwhelm the system before new containers are ready
@rubakMachineLearningPredictive2023a. These technical barriers erode confidence in
the platform.

The problem compounds for *instructors* who schedule synchronized activities like
live coding sessions or timed assessments. When many students attempt to launch IDEs
simultaneously at the start of a lab session, reactive scaling mechanisms cannot
provision resources quickly enough. Jenkins et al. and Valez et al. report that
technical difficulties with development environments "consume considerable
instructional time and create barriers for novice programmers," undermining
educational objectives and forcing instructors to allocate precious class time to
troubleshooting rather than teaching @jenkinsJavaWIDEInnovationOnline2010
@valezStudentAdoptionPerceptions2020a.
