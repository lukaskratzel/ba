= Motivation

Solving the startup latency challenges in cloud-based IDEs is relevant
scientifically, for educational outcomes, and the broader adoption of scalable
learning platforms. Prewarming can complete a significant amount of
initialization work upfront, as demonstrated in @fig:activity-diagram.

For *students*, immediate access to development environments transforms the learning
experience. Benotti et al. demonstrated that web-based coding tools with immediate
feedback positively affect student engagement and learning outcomes in programming
courses @benottiEffectWebbasedCoding2018. With shorter startup delays, students can
maintain momentum and focus on problem-solving.

From an *instructor's* perspective, reliable and responsive cloud IDE infrastructure
enables more ambitious and effective teaching strategies. If the infrastructure can
ensure capacity for synchronized activities, instructors can confidently design
interactive exercises and live coding demonstrations involving entire classes.
Krusche and Seitz showed that integrated automated assessment systems "help students
to realize their progress and to gradually improve their solutions", while reducing
instructor workload @kruscheArtemisAutomaticAssessment2018.

This work envisions a future where cloud-based development environments are as
readily available and reliable as opening a text editor on a local machine,
contributing to making high-quality programming education accessible to a larger and
more diverse student populations.

#figure(
  image("../../figures/activity-diagram.svg"),
  caption: [Desired activity flow showing seamless integration between a student and
    Theia Cloud],
) <fig:activity-diagram>
