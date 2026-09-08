# Open Device Partnership (ODP) documentation

This document will briefly review the value proposition of ODP and why it is the right technology for the future of firmware development, at the right time.

## Welcome to ODP!

ODP is a community-driven framework for building **secure**, **modular**, and **reusable** firmware components across a range of systems. Whether you’re interested in low-level boot firmware, embedded controller services, or integrating a complete firmware stack, ODP has something for you.

## What is ODP?

ODP brings modern software engineering practices—like memory safety and dependency injection—to the world of firmware. It leverages Rust to improve confidence, maintainability, and modularity across diverse hardware and system designs.

It also embraces existing standards like UEFI, DICE, ACPI, and EC protocols—but makes them more accessible and safer to implement.

## ODP projects

Patina (boot firmware) provides a UEFI compatible firmware interface written in the Rust language with a focus on memory safety and composition. Compatible with current UEFI device drivers and loaders but with a focus on the future. Patina documentation is covered in the [**Patina Book**](https://opendevicepartnership.github.io/patina/).

Secure Embedded Controller (EC) provides modern EC firmware written in Rust. Designed for safety and composability, it serves as a foundational layer for secure device management. Secure EC documentation is
covered in the [**Secure Embedded Controller Book**](https://opendevicepartnership.github.io/odp-embedded-controller/secure-ec-overview.html).

Unified Embedded Controller Services provides modern EC services firmware written in Rust. Designed for safety and composability, it serves as a foundational layer for secure EC services on Windows platforms.
EC services documentation is covered in the [**Embedded Controller Services section**](https://opendevicepartnership.github.io/odp-embedded-controller/specs/ec_interface/ec_interface.html) of the Secure EC Book.

