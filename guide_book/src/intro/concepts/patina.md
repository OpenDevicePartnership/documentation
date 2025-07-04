# Patina Background

## Overview

Firmware and UEFI firmware in particular has long been written in C. Firmware operates in a unique environment compared
to other system software. It is written to bootstrap a system often at the host CPU reset vector and as part of a chain
of trust established by a hardware rooted immutable root of trust. Modern PC and server firmware is extraordinarily
complex with little room for error.

We call the effort to evolve and modernize UEFI firmware in the Open Device Partnership (ODP) project "Patina". The
remainder of this document will discuss the motivation for this effort, a high-level overview of the current state of
Patina, and the current state of Rust in UEFI firmware.

### Firmware Evolution

From a functional perspective, firmware must initialize the operating environment of a device. To do so involves
integrating vendor code for dedicated microcontrollers, security engines, individual peripherals, System-on-Chip (SOC)
initialization, and so on. Individual firmware blobs may be located on a number of non-volatile media with very limited
capacity. The firmware must perform its functional tasks successfully or risk difficult to diagnose errors in higher
levels of the software stack that may impede overall device usability and debuggability.

These properties have led to slow but incremental expansion of host firmware advancements over time.

![Host FW Evolution](./images/uefi_evolution.png)

### Firmware Security

From a security perspective, firmware is an important component in the overall system Trusted Computing Base (TCB).
Fundamental security features taken for granted in later system software such as kernels and hypervisors are often
based on secure establishment in a lower layer of firmware. At the root is a concept of "trust".

While operating systems are attractive targets due to their ubiquity across devices and scale, attackers are
beginning to shift more focus to firmware as an attack surface in response to increasingly effective security measures
being applied in modern operating systems. While significant research has been devoted across the entire boot process,
UEFI firmware on the host CPU presents a unique opportunity to gain more visibility into early code execution details
and intercept the boot process before essential activities take place such as application of important security
register locks, cache/memory/DMA protections, isolated memory regions, etc. The result is code executed in this
timeframe must carry forward proper verification and measurement of future code while also ensuring it does not
introduce a vulnerability in its own execution.

### Performant and Reliable

From a performance perspective, firmware code is often expected to execute exceedingly fast. The ultimate goal is for
an end user to not even be aware such code is present. In a consumer device scenario, a user expects to press a power
button and immediately receive confirmation their system is working properly. At a minimum, a logo is often shown to
assure the user something happened and they will be able to interact with the system soon. In a server scenario,
fleet uptime is paramount. Poorly written firmware can lead to long boot times that impact virtual machine
responsiveness and workload scaling or, even worse, Denial of Service if the system fails to boot entirely. In an
embedded scenario, government regulations may require firmware to execute fast enough to show a backup camera within a
fixed amount of time.

All of this is to illustrate that firmware must perform important work in a diverse set of hardware states with code
that is as small as possible and do so quickly and securely. In order to transition implementation spanning millions of
lines of code written in a language developed over 50 years ago requires a unique and compelling alternative.

## Rust and Firmware

As previously stated, modern systems necessitate a powerful language that can support low-level programming with
maximum performance, reliability, and safety. While C has provided the flexibility needed to implement relatively
efficient firmware code, it has failed to prevent recurring problems around memory safety.

### Stringent Safety

Common pitfalls in C such as null pointer dereferences, buffer and stack overflows, and pointer mismanagement continue
to be at the root of high impact firmware vulnerabilities. These issues are especially impactful if they compromise
the system TCB. Rust is compelling for UEFI firmware development because it is designed around strong memory safety
without the usual overhead of a garbage collector. In addition, it enforces stringent type safety and concurrency rules
that prevent the types of issues that often lead to subtle bugs in low-level software development.

Languages aside, UEFI firmware has greatly fallen behind other system software in its adoption of basic memory
vulnerability mitigation techniques. For example, data execution protection, heap and stack guards, stack cookies,
and null pointer dereference detection is not present in the vast majority of UEFI firmware today. More advanced
(but long time) techniques such as Address Space Layout Randomization (ASLR), forward-edge control flow integrity
technologies such as x86 Control Flow Enforcement (CET) Indirect Branch Tracking (IBT) or Arm Branch Target
Identification (BTI) instructions, structured exception handling, and similar technologies are completely absent in
most UEFI firmware today. This of course exacerbates errors commonly made as a result of poor language safety.

Given firmware code also runs in contexts with high privilege level such as System Management Mode (SMM) in x86,
implementation errors can be elevated by attackers to gain further control over the system and subvert other
protections.

### Developer Productivity

The Rust ecosystem brings more than just safety. As a modern language firmware development can now participate
in concepts and communities typically closed to firmware developers. For example:

- Higher level multi-paradigm programming concepts such as those borrowed from functional programming in addition to
  productive polymorphism features such as generics and traits.

- Safety guarantees that prevent errors and reduce the need for a myriad of static analysis tools with flexibility to
  still work around restrictions when needed in an organized and well understood way (unsafe code).

### Modern Tooling

Rust includes a modern toolchain that is well integrated with the language and ecosystem. This standardizes tooling
fragmented across vendors today and lends more time to firmware development. Examples of tools and community support:

- An official package management system with useful tools such as first-class formatters and linters that reduce
  project-specific implementations and focus discussion on functional code changes.

- High quality reusable bundles of code in the form of crates that increase development velocity and engagement with
  other domain experts.

- Useful compilation messages and excellent documentation that can assist during code development.

- A modern testing framework that allows for unit, integration, and on-platform tests to be written in a consistent
  way. Code coverage tools that are readily available and integrate seamlessly with modern IDEs.

Rust's interoperability with C code is also useful. This enables a phased adoption pathway where codebases can start
incorporating Rust while still relying upon its extensive pre-existing code. At the same time, Rust has been conscious
of low-level needs and can precisely structure data for C compatibility.

## Patina in ODP

The Patina team in ODP plans to participate within the open Rust development community by:

1. Engaging with the broader Rust community to learn best practices and share low-level system programming knowledge.
2. Leveraging and contributing back to popular crates and publishing new crates that may be useful to other projects.
   - A general design strategy is to solve common problems in a generic crate that can be shared and then integrate it
     back into firmware.
3. Collaborating with other firmware vendors and the UEFI Forum to share knowledge and best practices and
   incorporate elements of memory safety languages like Rust into industry standard specifications where appropriate.
   Some specifications have interfaces defined around concepts and practices common in unsafe languages that could
   be improved for safety and reliability.

Looking forward, we're continuing to expand the coverage of our firmware code written in Rust. We are excited to
continue learning more about Rust in collaboration with the community and our partners.