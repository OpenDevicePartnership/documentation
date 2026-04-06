# The tracks of ODP

ODP is a comprehensive umbrella addressing a span of firmware concerns:

- Boot Firmware / UEFI  (Patina)
- Embedded Controller components and services (EC)
- Security firmware and architecture

Development efforts for these domains are often not performed by the same teams, and these pieces are often built independently of each other and only brought together in the end.

ODP does not usurp this development paradigm but rather empowers it further through the commonality of the Rust language and tools, and through a shared philosophy of modularity and agility.


## How to continue with this book

This book is geared to a couple of different distinct audiences.  If you are concerned primarily with any one of the particular 'tracks' of ODP and are interested in a guide to which ODP repositories are relevant for that track, continue with [What is in ODP?](./what/what.md)

If you are a __Firmware Engineer__ you likely will want to continue following ahead into the hands-on projects for building Embedded Controller components and services, and integrating these into an EC simulation and test application. To continue on this track, simply continue to the next article.

Depending on your interest or role, we offer guided tracks through the documentation:

#### Subject-based:
- 🏅 [**Value Proposition**](../tracks/value_proposition/track_overview.md)
  Understand the core benefits of ODP, including security, modularity, and cross-domain coherence.

- 🛫 [**Patina Boot Firmware**](../tracks/patina/track_overview.md)  
  Learn to build UEFI firmware with Rust using the Patina framework.

- 🔋 [**Embedded Controller and Services**](../tracks/embedded_controller/track_overview.md)
  Dive into EC subsystems like battery, charger, and thermal control with real component walkthroughs.

- 🔐 [**Security Architecture**](../tracks/security/track_overview.md)  
  Explore trusted boot, firmware identity, and the DICE model.



#### Role-based:

- 🔧 [**Integrator**](../tracks/integrator/track_overview.md)
    Discover how to integrate ODP components into larger systems.

- 🧑‍🤝‍🧑 [**Contributor**](../tracks/contributor/track_overview.md)
    Get involved in the ODP community by contributing code, documentation, or reporting issues.

Technical readers may also be interested in the [Specifications](./specs/specifications.md) section, which provides detailed technical specifications for ODP components and services.

---




