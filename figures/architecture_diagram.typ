#import "/utils/diagram.typ": diagram

// Architecture diagram showing Artemis-Theia Cloud integration
// This is a placeholder - should be replaced with a proper UML component diagram

#diagram(
  caption: [System Architecture: Artemis-Theia Cloud Integration with Predictive Scaling. The diagram shows the main components: Artemis LMS provides course schedules and triggers session requests; the Forecasting Service analyzes historical data and schedules to predict demand; the Predictive Scaling Controller adjusts warm pool sizes; the Theia Cloud Operator manages prewarmed containers; and students receive instant access to IDE sessions.],
  short-caption: [System Architecture]
)[
  #block(
    width: 100%,
    height: 300pt,
    fill: rgb("#f0f0f0"),
    stroke: 1pt + black,
    inset: 10pt
  )[
    #align(center)[
      #text(size: 14pt, weight: "bold")[Artemis-Theia Cloud Predictive Scaling Architecture]
      
      #v(10pt)
      
      #grid(
        columns: (1fr, 1fr, 1fr),
        rows: (auto, auto, auto),
        gutter: 15pt,
        
        // Top Layer - User Interface
        grid.cell(colspan: 3)[
          #block(fill: rgb("#e3f2fd"), stroke: 1pt, inset: 8pt, radius: 4pt)[
            *Artemis LMS*\
            Course Schedules | Assignment Deadlines | Student Interface
          ]
        ],
        
        // Middle Layer - Intelligence
        grid.cell(colspan: 2)[
          #block(fill: rgb("#fff3e0"), stroke: 1pt, inset: 8pt, radius: 4pt)[
            *Forecasting Service*\
            ML Models | Historical Data | Demand Prediction
          ]
        ],
        
        grid.cell()[
          #block(fill: rgb("#fff3e0"), stroke: 1pt, inset: 8pt, radius: 4pt)[
            *Scaling Controller*\
            Policy Engine | Safety Margins
          ]
        ],
        
        // Bottom Layer - Infrastructure
        grid.cell(colspan: 3)[
          #block(fill: rgb("#f1f8e9"), stroke: 1pt, inset: 8pt, radius: 4pt)[
            *Theia Cloud Operator (Kubernetes)*\
            Warm Pool Manager | Session Handler | Container Orchestration
          ]
        ],
        
        // Base Layer
        grid.cell(colspan: 3)[
          #block(fill: rgb("#fce4ec"), stroke: 1pt, inset: 8pt, radius: 4pt)[
            *Prewarmed IDE Containers*\
            Ready-to-use Theia instances with language servers
          ]
        ],
      )
      
      #v(5pt)
      #text(size: 9pt)[
        Arrows: ↓ Session requests, ← Demand signals, → Pool adjustments, ↕ Container binding
      ]
    ]
  ]
]

