# Diagram Planning

Already have:
- Introduction activity diagram for basic prewarming flow

Add:
- subsytem decomposition with deployment environment grouping -> show deployment environments and components
    - Show entire sytem, including what components sit in which system
    - Include at least: Scorpio, data bridge, theia ide, operator, service, gateway, prewarming pool, ingress mananger 
- Sequence diagram for prewarming pool adjustment
    - Shows how an update to the appdefinition CRD triggers a pool adjustment
- Sequence diagram for session startup
    - Shows how creation of the session CRD triggers a session startup. Include the service which creates the sesion resource and publishes the session URL.
- Routing propagation flow -> activity/ sequence
    - Shows how a route update is propagated through the system using kubernetes gateway api
    - Includes HTTPRoute resource update and operator probing the route from 'outside'
- Sequence diagram of the end-to-end startup flow, to define optimization scope (backend session startup)
    - Very high level, properly early in requriements/ architecture to draw optimization boundary