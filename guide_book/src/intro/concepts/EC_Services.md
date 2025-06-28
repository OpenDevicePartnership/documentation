# EC Services

Embedded controller services are available for the operating system to call for various higher-level purposes dictated by specification.
The Windows Operating system defines some of these standard services for its platform.

These service interfaces include those for:
- debug services
- firmware management services
- input management services
- oem services
- power services
- time services

Services may be available for operating systems other than Windows.

OEMs may wish to implement their own services as part of their product differentiation.

### EC Service communication protocols
With a communication channel protocol established between OS and EC, operating system agents and applications are able to monitor and operate peripheral controllers from application space.

This scope comes with some obvious security ramifications that must be recognized.

Implementations of ODP may be architected for both Secure and Non-Secure system firmware designs, as previously discussed.

![Secure Architecture](./images/image1.png)

In the diagram above, the dark blue sections are those elements that are part of normal (non-secure) memory space and may be called
from a service interface directly.  As we can see on the Non-Secure side, the ACPI transport channel has access to the EC component implementations either directly or through the FF-A (Firmware Framework Memory Management Protocol).

### FF-A
The Firmware Framework Memory Management Protocol [(Spec)](https://developer.arm.com/documentation/den0140/latest/)
describes the relationship of a hypervisor controlling a set of secure memory partitions with configurable access and ownership attributes and the protocol for exchanging information between these virtualized contexts.

FF-A is available for Arm devices only.  A common solution for x64 is still in development. For x64 implementations, use of SMM is employed to orchestrate hypervisor access using the [Hafnium] Rust product.

In a Non-Secure implementation _without_ a hyperviser, the ACPI connected components can potentially change the state within any accessible memory space.  An implementation with a hypervisor cannot.  It may still be considered a "Non-Secure" implementation, however, as the ACPI data itself is unable to be verified for trust.

In a fully "Secure" implementation, controller code is validated at boot time to insure the trust of the data it provides. Additionally, for certain types of data, digital signing and/or encryption may be used on the data exchanged to provide an additional level of trust.


