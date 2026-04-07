# Diagram Planning

Already have:
- Introduction activity diagram for basic prewarming flow
- subsytem decomposition with deployment environment grouping -> show deployment environments and components
    - Show entire sytem, including what components sit in which system
    - Include at least: Scorpio, data bridge, theia ide, operator, service, gateway, prewarming pool, ingress mananger 
- Sequence diagram for session startup
    - Shows how creation of the session CRD triggers a session startup. Include the service which creates the sesion resource and publishes the session URL.