#import "/utils/diagram.typ": diagram

// Sequence diagram showing predictive scaling workflow
// This is a placeholder - should be replaced with a proper UML sequence diagram

#diagram(
  caption: [Predictive Scaling and Session Binding Sequence. The workflow shows: (1) Forecasting Service predicts demand based on schedules and historical data, (2) Scaling Controller updates warm pool size, (3) Operator provisions prewarmed containers, (4) Student requests session through Artemis, (5) Session Handler binds user to prewarmed container with security policies, (6) Student receives instant access to ready IDE.],
  short-caption: [Predictive Scaling Workflow]
)[
  #block(
    width: 100%,
    height: 350pt,
    fill: rgb("#fafafa"),
    stroke: 1pt + black,
    inset: 10pt
  )[
    #align(left)[
      #text(size: 14pt, weight: "bold")[Sequence: Predictive Scaling & Session Binding]
      
      #v(10pt)
      
      #table(
        columns: (auto, 1fr),
        stroke: none,
        row-gutter: 8pt,
        align: (left, left),
        
        [*1.*], [*Forecast Phase (T-60 minutes)*\
        Forecasting Service analyzes: historical session data, course schedules from Artemis, current time/day patterns → Generates demand prediction: "Expected 150 sessions at 14:00"],
        
        [*2.*], [*Scaling Decision*\
        Scaling Controller receives forecast → Applies safety margin (P90 + 10%) → Calculates target: 165 warm containers → Updates `AppDefinition.spec.minInstances = 165`],
        
        [*3.*], [*Proactive Provisioning*\
        Theia Cloud Operator detects `minInstances` change → Creates 165 Kubernetes Deployments/Services → Pulls images, starts containers, initializes Theia → Marks containers as "ready" in warm pool],
        
        [*4.*], [*Student Session Request (T=14:00)*\
        Student clicks "Open IDE" in Artemis assignment → Artemis calls Theia Cloud REST API: `POST /sessions/start` with user token, workspace ID, app definition],
        
        [*5.*], [*Instant Binding*\
        Session Handler selects available prewarmed container from pool → Injects OAuth2 proxy config with user email → Updates Ingress rules with session-specific URL → Validates authentication propagation → Returns session URL to Artemis],
        
        [*6.*], [*Immediate Access*\
        Student redirected to session URL (< 5 seconds) → Authentication validated by OAuth2 proxy → Theia IDE loads instantly (already running) → Student begins coding],
        
        [*7.*], [*Pool Replenishment*\
        Operator detects pool size below target → Provisions replacement container → Maintains pool at forecasted level for remaining demand],
      )
    ]
  ]
]

