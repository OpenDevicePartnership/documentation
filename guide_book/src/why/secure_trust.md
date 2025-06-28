# Security

Reduce firmware attack surface significantly, and meet modern security expectations using proven tools and patterns.

## Security and Trustworthiness from the Ground Up

> _“If the foundation is weak, nothing built on top can be trusted.”_

Rust is a modern, memory-safe language that mitigates entire classes of vulnerabilities endemic to C memory management, buffer overflows, use-after-free, and so forth by detecting and addressing these issues at compile time -- so there are few, if any, unpleasant surprises at runtime.

ODP is foundationally centered around Rust and not only embraces these philosophies, it defines patterns that further enhance the memory-safe paradigm, by preventing unauthorized access between ownership domains and guarding against possible malicious intrusions while implementing proven industry-standard patterns.

```mermaid
flowchart LR
  Start[Power On] --> ROM
  ROM --> FirmwareCheck[Validate Firmware Signature]
  FirmwareCheck --> DXECore[Load DXE Core]
  DXECore --> OSLoader[Invoke Bootloader]
  OSLoader --> OSVerify[Validate OS Signature]
  OSVerify --> OSBoot[Launch OS]
  OSBoot --> Ready[Platform Ready]
```

Adoption of standards and patterns of DICE and EL2 Hypervisor supported architectures -- from a Rust-driven baseline - enables a hardware-rooted chain of trust across boot phases, aligning with NIST and platform security goals and requirements.

ODP makes component modularity and portability with a transparent provenance a practical and safe proposition by making it feasiable to audit and verify firmware behavior in specifically constrained ways.

