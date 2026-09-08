# ODP Repositories

There are over 60 repositories that make up the whole of the ODP umbrella. Many of these are simply HAL definitions for particular hardware, but others define the critical business logic and data traits that comprise the portable and modular framework ODP provides. Many of the crates defined by these repositories may be interdependent.  

Other repositories represented here define tools and tests that are useful in development.

---

## Patina

| Repository | Description | Tag |
|------------|-------------|-----|
| [Developing UEFI with Rust](https://opendevicepartnership.github.io/patina/) | _(Document)_ Overview of ODP Patina and Rust, contribution guide, and build setup. | Patina |
| [patina](https://github.com/OpenDevicePartnership/patina) | Library of crates implementing Patina UEFI code. | Patina |
| [patina-dxe-core-qemu](https://github.com/OpenDevicePartnership/patina-dxe-core-qemu) | Builds `.efi` image from Patina libraries and local components for QEMU. | Patina |
| [patina-qemu](https://github.com/OpenDevicePartnership/patina-qemu) | QEMU platform firmware integrating `.efi` Patina binaries. | Patina |
| [patina-readiness-tool](https://github.com/OpenDevicePartnership/patina-readiness-tool) | Tests platform readiness for Patina. | Patina |
| [patina-fw-patcher](https://github.com/OpenDevicePartnership/patina-fw-patcher) | Speeds up incremental firmware build iterations vs. full `stuart_build`. | Patina |
| [patina-mtrr](https://github.com/OpenDevicePartnership/patina-mtrr) | MTRR (Memory Type Range Register) library for x86_64. | Patina |
| [patina-paging](https://github.com/OpenDevicePartnership/patina-paging) | Common paging support for ARM64 and x64. | Patina |
| [uefi-corosensei](https://github.com/OpenDevicePartnership/uefi-corosensei) | UEFI fork of corosensei crate. | Patina |

---

## EC

| Repository | Description | Tag |
|------------|-------------|-----|
| [embedded-services](https://github.com/OpenDevicePartnership/embedded-services) | Service definitions wrapping HAL components. | EC |
| [soc-embedded-controller](https://github.com/OpenDevicePartnership/soc-embedded-controller) | Demonstration of EC firmware built using ODP components. | EC |
| [embedded-batteries](https://github.com/OpenDevicePartnership/embedded-batteries) | SmartBattery spec traits for HAL abstraction. | EC |
| [embedded-sensors](https://github.com/OpenDevicePartnership/embedded-sensors) | Embedded sensors HAL abstraction. | EC |
| [embedded-fans](https://github.com/OpenDevicePartnership/embedded-fans) | HAL definition for fan control. | EC |
| [embedded-power-sequence](https://github.com/OpenDevicePartnership/embedded-power-sequence) | SoC power on/off abstraction. | EC |
| [embedded-cfu](https://github.com/OpenDevicePartnership/embedded-cfu) | Implements Windows CFU commands/responses. | EC |
| [embedded-usb-pd](https://github.com/OpenDevicePartnership/embedded-usb-pd) | Common types for USB-PD. | EC |
| [embedded-mcu](https://github.com/OpenDevicePartnership/embedded-mcu) | MCU traits and libraries for hardware peripherals. | EC |
| [hid-embedded-controller](https://github.com/OpenDevicePartnership/hid-embedded-controller) | HID over I2C demo library for ECs. | EC |
| [ec-test-app](https://github.com/OpenDevicePartnership/ec-test-app) | Test application to exercise EC functionality via ACPI. | EC |
| [ffa](https://github.com/OpenDevicePartnership/ffa) | FF-A services in Rust for Hafnium. | EC |
| [haf-ec-service](https://github.com/OpenDevicePartnership/haf-ec-service) | Rust EC services for Hafnium. | EC |
| [ec-slimloader](https://github.com/OpenDevicePartnership/ec-slimloader) | Stage-one EC bootloader. | EC |
| [ec-slimloader-descriptors](https://github.com/OpenDevicePartnership/ec-slimloader-descriptors) | Boot descriptors for multi-image firmware scenarios. | EC |
| *(plus all drivers, PACs, and HAL crates such as `bq24773`, `bq40z50`, `tmp108`, `mec17xx-pac`, `npcx490m-examples`, `embassy-*`, etc.)* | | EC |

---

## Security

| Repository | Description | Tag |
|------------|-------------|-----|
| [rust_crate_audits](https://github.com/OpenDevicePartnership/rust-crate-audits) | Aggregated Rust crate audits. | Security |

---

## Tooling

| Repository | Description | Tag |
|------------|-------------|-----|
| [odp-utilites](https://github.com/OpenDevicePartnership/odp-utilites) | Rust utilities for embedded development. | Tooling |
| [systemview-tracing](https://github.com/OpenDevicePartnership/systemview-tracing) | Adds Segger SystemView tracing to ODP. | Tooling |
| [nxp-header](https://github.com/OpenDevicePartnership/nxp-header) | CLI utility for NXP image headers. | Tooling |
