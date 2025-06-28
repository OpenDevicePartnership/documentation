# Patina
## (Boot Firmware)

___Patina___ is the codename for ODP's Rust-based SDK and framework for UEFI-compliant boot firmware development.

It is based upon the venerable __UEFI__ standard and doesn't seek to reinvent the process of this well-known
framework, as it necessarily re-implements these familiar patterns in Rust instead of C.

### A review of UEFI
__UEFI__ stands for _Unified Extensible Firmware Interface_ and can be described as broken into a series of layers, as this diagram shows:

![PI_Boot_phases](./images/PI_Boot_Phases.jpg)
_(diagram source: TianoCore, , illustrating the PI Boot Flow from SEC to RT phase)_

This boot-time firmware is executed by the platform main CPU on startup/reset and proceeds through the stages shown in the diagram.  As part of its initialization, it may communicate with the embedded system microcontrollers that are also under the control of ODP rust drivers to initiate and orchestrate them to a starting state.

While the majority of ODP development focuses on the __DXE__ phase, Patina also supports implementation in the __PEI__, __SEC__ and other phases.  

Some aspects of UEFI, especially those that have already been deprecated, may not be supported under ODP.  These are legacy services, UI facilitators, and some Runtime Support components that either no longer serve a core purpose or can more effectively be implemented in other ways within ODP.




