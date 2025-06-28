# Cross-Domain Coherence

ODP is not just a patch atop of old layers.  It is explicitly aligning system layers to reduce duplication, ambiguity, and failure points.

ODP is not just a firmware stack, but a vision that unites the embedded controller, main firmware, and even secure services under a coherent design and tooling approach.

 
## Common patterns with clearly defined lanes

> _“Secure systems require secure interfaces — everywhere.”_
 
Shared services and conventions allow clear division of responsibility between firmware, EC, and OS—while promoting reuse and coordination.

```mermaid
graph LR
    Host[Host Domain] --> HostServiceA
  Host --> HostServiceB

  HostServiceA --> HostDriverA
  HostServiceB --> HostDriverB

  EC[Embedded Controller Domain] --> ECServiceA
  EC --> ECServiceB

  subgraph Shared Interface
    HostServiceA <---> ECServiceA
    HostServiceB <---> ECServiceB
  end
  ```