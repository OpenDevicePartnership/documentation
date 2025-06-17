# What is in ODP?

There are over 60 repositories that make up the whole of the ODP umbrella.  Many of these are simply HAL definitions for particular hardware, but others define the critical business logic and data traits that comprise the portable and modular framework ODP provides.  Many of the crates defined by these repositories may be interdependent.
Other repositories represented here define tools and tests that are useful in development.


| Repository | Description | Patina | EC | Security | Tooling | Other |
|------------|-------------|--------|----|----------|---------|--------|
| [Developing UEFI with Rust](https://sturdy-adventure-nv32gqw.pages.github.io/) | _(Document)_ An overview of using ODP Patina and Rust, how to contribute to ODP, and how to setup and build DXE Core components. |✅ |  |  |  | ✅ |
| [patina](https://github.com/OpenDevicePartnership/patina?tab=readme-ov-file#patina) | This maintains a library of crates that implement UEFI-like code in Rust. This defines all of the reusable | ✅ |  |  |  |  |
| [patina-dxe-core-qemu](https://github.com/openDevicePartnership/patina-dxe-core-qemu?tab=readme-ov-file#qemu-dxe-core-binaries) | This repository holds the code responsible for pulling in reusable Rust DXE Core components from the Patina SDK, combining these with locally defined custom components, and building the resulting `.efi` image that may be loaded into the QEMU emulator. | ✅ |  |  |  |  |
| [patina-qemu](https://github.com/openDevicePartnership/patina-qemu?tab=readme-ov-file#patina-platform-repository) | This repository supplies a platform wrapper that loads the `.efi` firmware into QEMU using EDK build tools (`stuart_build`) from the `.efi` file indicated at build time. | ✅ |  |  |  |  |
| [patina-fw-patcher](https://github.com/openDevicePartnership/patina-fw-patcher?tab=readme-ov-file#firmware-rust-patcher) | This repository simplifies the iterative turnaround for incremental builds in a workflow, once one has been established, able to forego the full `stuart_build` process for each code update. | ✅ |  |  | ✅ |  |
| [patina-mtrr](https://github.com/openDevicePartnership/patina-mtrr?tab=readme-ov-file#introduction) | This repository supports a MTRR(Memory Type Range Registers) API that helps program MTRRs on x86_64 architecture. | ✅ |  |  |  |  |
| [patina-paging](https://github.com/openDevicePartnership/patina-paging?tab=readme-ov-file#cpu-paging-support) | Common paging support for various architectures such as ARM64 and X64 | ✅ |  |  |  |  |
| [embedded_services](https://github.com/OpenDevicePartnership/embedded-services?tab=readme-ov-file#ec-services) | Business logic service definitions and code for wrapping and controlling HAL-level component definitions into a service context. |  | ✅ |  |  |  |
| [soc-embedded-controller](https://github.com/OpenDevicePartnership/soc-embedded-controller) | Demonstration of EC firmware built using ODP components |  | ✅ |  |  |  |
| [embedded-batteries](https://github.com/OpenDevicePartnership/embedded-batteries?tab=readme-ov-file#embedded-batteries) | SmartBattery Specification support defining traits for HAL abstraction. |  | ✅ |  |  |  |
| [embedded-sensors](https://github.com/OpenDevicePartnership/embedded-sensors?tab=readme-ov-file#embedded-sensors) | Defines the embedded sensors interface for HAL abstraction. Designed for use with `embedded-services`. |  | ✅ |  |  |  |
| [embedded-fans](https://github.com/OpenDevicePartnership/embedded-fans?tab=readme-ov-file#embedded-fans) | HAL definition for fan control. Designed for use with `embedded-services`. |  | ✅ |  |  |  |
| [embedded-power-sequence](https://github.com/OpenDevicePartnership/embedded-power-sequence?tab=readme-ov-file#embedded-power-sequence) | Abstraction of SoC power on/off via firmware control. |  | ✅ |  |  |  |
| [embedded-cfu](https://github.com/OpenDevicePartnership/embedded-cfu?tab=readme-ov-file#embedded-cfu) | Implements commands and responses as structs per the Windows CFU spec. |  | ✅ |  |  |  |
| [embedded-usb-pd](https://github.com/OpenDevicePartnership/embedded-usb-pd?tab=readme-ov-file#embedded-usb-pd) | common types for usb pd.  May be necessary as a dependency for several `embedded-services` builds. |  | ✅ |  |  |  |
| [embedded-mcu](https://github.com/OpenDevicePartnership/embedded-mcu?tab=readme-ov-file#embedded-mcu) | an agnostic set of MCU-related traits and libraries for manipulating hardware peripherals in a generic way. |  | ✅ |  |  |  |
| [hid-embedded-controller](https://github.com/OpenDevicePartnership/hid-embedded-controller?tab=readme-ov-file#hid-embedded-controller) | Embedded Controller HID library / HID over I2C demo |  | ✅ |  |  |  |
| [ec-test-app](https://github.com/OpenDevicePartnership/ec-test-app?tab=readme-ov-file#ec-test-app) | Test application to exercise EC functionality through ACPI from the OS |  | ✅ |  |  | ✅ |
| [ffa](https://github.com/OpenDevicePartnership/ffa?tab=readme-ov-file#ff-a-firmware-framework-for-armv8-a-profile) | FFA for Rust services running under Hafnium through FF-A |  | ✅ | ✅ |  |  |
| [haf-ec-service](https://github.com/OpenDevicePartnership/haf-ec-service?tab=readme-ov-file#hafnium-ec-service-in-rust) | Rust services for Hafnium supported EC architectures. |  | ✅ | ✅ |  |  |
| [patina-mtrr](https://github.com/openDevicePartnership/patina-mtrr?tab=readme-ov-file#introduction) | This repository supports a MTRR(Memory Type Range Registers) API that helps program MTRRs on x86_64 architecture. | ✅ |  | ✅  |  |  |
| [patina-paging](https://github.com/openDevicePartnership/patina-paging?tab=readme-ov-file#cpu-paging-support) | Common paging support for various architectures such as ARM64 and X64 | ✅ |  | ✅  |  |  |
| [rust_crate_audits](https://github.com/OpenDevicePartnership/rust-crate-audits?tab=readme-ov-file#open-device-partnerships-rust-crate-audits) | Aggregated audits for Rust crates by the Open Device Partnership |  |  | ✅ |  | ✅ |
| [uefi-bds](https://github.com/OpenDevicePartnership/uefi-bds) | UEFI Boot Device Selection DXE driver | ✅ | | | | ✅ |
| [uefi-corosensei](https://github.com/OpenDevicePartnership/uefi-corosensei) |  UEFI fork of the corosensei crate | ✅ | | | | ✅ |
| [modern-payload](https://github.com/OpenDevicePartnership/modern-payload) | Slimmed down UEFI payload | ✅ | | | | ✅ |
| [slimloader](https://github.com/OpenDevicePartnership/slimloader) | First stage boot loader for AArch64 | ✅ | | | | ✅ |
| [ec-slimloader](https://github.com/OpenDevicePartnership/ec-slimloader) | A light-weight stage-one bootloader for loading an app image as configured by ec-slimloader-descriptors | ✅ | ✅ | | | ✅ |
| [ec-slimloader-descriptors](https://github.com/OpenDevicePartnership/name) | Boot-time application image management descriptors for enabling multi-image firmware boot scenarios, such as those provided by CFU  | ✅ | ✅ | | | ✅ |
| [odp-utilites](https://github.com/OpenDevicePartnership/odp-utilites) | A collection of Rust utilities focused on embedded systems development. | | | | ✅ | ✅ |
| [systemview-tracing](https://github.com/OpenDevicePartnership/systemview-tracing) | Support for adding Segger SystemView tracing to ODP projects | | | | ✅ | ✅ |
| [nxp-header](https://github.com/OpenDevicePartnership/nxp-header) | CLI utility to modify binary firmware image file to add NXP image header | | | | ✅ | ✅ |
| [bq24773](https://github.com/OpenDevicePartnership/bq24773) | Driver for TI BQ24773 battery charge controller | |✅ | | | ✅ |
| [bq25713](https://github.com/OpenDevicePartnership/bq25713) | Driver for TI BQ25713 battery charge controller | |✅ | | | ✅ |
| [bq25730](https://github.com/OpenDevicePartnership/bq25730) | Driver for TI BQ25730 battery charge controller | |✅ | | | ✅ |
| [bq25770g](https://github.com/OpenDevicePartnership/bq25770g) | Driver for TI BQ2577G battery charge controller | |✅ | | | ✅ |
| [bq25773](https://github.com/OpenDevicePartnership/bq25773) | Driver for TI BQ25773 battery charge controller | |✅ | | | ✅ |
| [bq40z50](https://github.com/OpenDevicePartnership/bq40z50) | Driver for TI BQ40Z50 Li-ion battery pack manager | |✅ | | | ✅ |
| [tmp108](https://github.com/OpenDevicePartnership/tmp108) | Driver for TI TMP108 digital temperature sensor | |✅ | | | ✅ |
| [cec17-data](https://github.com/OpenDevicePartnership/cec17-data) | Single meta-PAC supporting all variants within the MEC/CEC family of MCUs produced by Microchip | |✅ | | | ✅ |
| [mec17xx-pac](https://github.com/OpenDevicePartnership/mec17xx-pac) | Peripheral Access Crate (PAC) for the Microchip MEC17xx family of MCUs | |✅ | | | ✅ |
| [mimxrt633s-pac](https://github.com/OpenDevicePartnership/mimxrt633s-pac) | Embedded PAC for NXP RT633s MCU | |✅ | | | ✅ |
| [mimxrt685s-pac](https://github.com/OpenDevicePartnership/mimxrt685s-pac) | Rust PAC created with svd2rust for MIMXRT685s family of MCUs | |✅ | | | ✅ |
| [mimxrt685s-examples](https://github.com/OpenDevicePartnership/mimxrt685s-examples) | Collection of examples demonstrating the use of the mimxrt685s-pac crate | |✅ | | | ✅ |
| [npcx490m-pac](https://github.com/OpenDevicePartnership/npcx490m-pac) | Embedded PAC for Nuvoton NPCX490M MCU | |✅ | | | ✅ |
| [npcx490m-examples](https://github.com/OpenDevicePartnership/npcx490m-examples) | Examples for Nuvoton NPCX490M Embedded PAC | |✅ | | | ✅ |
| [embedded-regulator](https://github.com/OpenDevicePartnership/embedded-regulator) | Embedded HAL for system voltage regulators | |✅ | | | ✅ |
| [embedded-keyboard-rs](https://github.com/OpenDevicePartnership/embedded-keyboard-rs) | Driver for embedded system matrix keyboards | |✅ | | | ✅ |
| [rt4531](https://github.com/OpenDevicePartnership/rt4531) | Driver for Richtek RT4531 keyboard backlight controller | |✅ | | | ✅ |
| [tps65994ae](https://github.com/OpenDevicePartnership/tps65994ae) | Driver for TI TPS65994AE USB-C power delivery controller | |✅ | | | ✅ |
| [tps6699x](https://github.com/OpenDevicePartnership/tps6699x) | Driver for TI TPS6699x USB-C power delivery controller | |✅ | | | ✅ |
| [is31fl3743b](https://github.com/OpenDevicePartnership/is31fl3743b) | Driver for Lumissil IS31FL3743B LED matrix controller | |✅ | | | ✅ |
| [pcal6416a](https://github.com/OpenDevicePartnership/pcal6416a) | Rust driver for IO Expander pcal6416a | |✅ | | | ✅ |
| [embassy-imxrt](https://github.com/OpenDevicePartnership/embassy-imxrt) | Embassy HAL for NXP IMXRT MCU family | |✅ | | | ✅ |
| [embassy-microchip](https://github.com/OpenDevicePartnership/embassy-microchip) | Embassy HAL for Microchip MEC17xx and MEC16xx series MCUs | |✅ | | | ✅ |
| [embassy-npcx](https://github.com/OpenDevicePartnership/embassy-npcx) | Embassy HAL for Nuvoton NPCX MCU family | |✅ | | | ✅ |
| [lis2dw12-i2c](https://github.com/OpenDevicePartnership/lis2dw12-i2c) | Rust driver for STMicroelectronics LIS2DW12 accelerometer | |✅ | | | ✅ |
| [mimxrt600-fcb](https://github.com/OpenDevicePartnership/mimxrt600-fcb) | Flash Control Block for MIMXRT600 MCUs | |✅ | | | ✅ |
| [MX25U1632FZUI02](https://github.com/OpenDevicePartnership/MX25U1632FZUI02) | Rust based driver for flash part MACRONIX/MX25U1632FZUI02 | |✅ | | | ✅ |
