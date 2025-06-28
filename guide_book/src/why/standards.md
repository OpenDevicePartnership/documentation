# Alignment with Industry Trends and Standards

ODP is forward-facing from its original concept, and embodied in its design.  Adoption of ODP positions you at the forefront of secure, future-facing firmware innovation.

> _“ODP doesn’t rewrite the rules — it implements them with confidence.”_

### Perfectly Timed
ODP taps into the growing ecosystem momentum around Rust and embedded standards. Rust adoption at Microsoft, Google, and the Linux kernel reflects a broader industry shift.

### Open Source and Collaborative
ODP Encourages upstream contributions and compliance with modern firmware interfaces (UEFI, ACPI, DICE).

An open collaboration model invites cross-vendor reuse and innovation while building upon existing standards known to the industry.

```mermaid
graph TD
  A1[UEFI Spec] --> B1[DXE Core]
  A2[ACPI] --> B2[Runtime Services]
  A3[DICE] --> B3[Secure Boot]
  A4[SPDM] --> B3
  A5[DMTF] --> B4[Mgmt Layer]

  B1 --> C[ODP Framework]
  B2 --> C
  B3 --> C
  B4 --> C
```