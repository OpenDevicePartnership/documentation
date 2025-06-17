# Concepts

The core firmware of a modern computing device is much more sophisticated than it was a couple of decades ago.
What started out on early computers as the Basic Input-Output System (BIOS) firmware that allowed keyboard input, clock support, and maybe serial terminal output designed to give the most rudimentary of control to a system before it has the opportunity to load the operating system, as well as the initial bootstrap loader to bring that onboard, has grown into an orchestration of individual microcontroller-driven subsystems that manage a variety of input devices, cryptography subsystems,
basic networking, power management, and even proprietary AI models.

Beyond handling the boot-time tasks, some of this lower-level firmware is meant to run autonomously in the background to monitor and adjust to operating conditions.  For example, a thermal control subsystem will take measures to cool the computer if the CPU temperature exceeds optimal levels, or a battery charging subsystem must correctly detect when the power cord has been plugged in or removed and execute the steps necessary to charge the system.  Such tasks are generally controlled by one or more Embedded Controllers, oftentimes found as a single System-on-Chip (SOC) construction.

Embedded Controllers are the unsung heroes of the modern laptop, quietly handling power management, thermal control, 
battery charging, lid sensors, keyboard scan matrices, and sometimes even security functions. 
There's a surprising amount of complexity tucked away in that little chip.

The drivers and handlers responsible for managing these subsystems must be secure, reliable, and easy to adopt with confidence. 
This calls for a standardized, community-moderated approach—one that still leaves room for innovation and platform-specific 
differentiation.

There are many proven standards that define and govern the development of this firmware. 
For example, __UEFI__ (_Unified Extensible Firmware Interface_) defines a standard for boot-level firmware in a series of layers, and __DICE__ (Device Identity Composition Engine) defines a standard for cryptographic verification of firmware components for a security layer.

Hardware components issue events or respond to signals transmitted over data buses such as eSPI,UART, I2C/I3C. These signals 
are monitored or driven by firmware, forming the basis for orchestrating and governing hardware behavior

Historically, much of this firmware has been vendor-supplied and tightly coupled to specific EC or boot hardware. It's often written in C or even assembly, and may be vulnerable to memory-unsafe operations or unintended behavior introduced by seemingly harmless changes.

The Open Device Partnership doesn't replace the former standards, but it defines a pattern for implementing this architecture in Rust.

As computing devices grow more complex and user data becomes increasingly sensitive, the need for provable safety 
and security becomes critical.

Rust offers a compelling alternative. As a systems programming language with memory safety at its core, Rust enables secure, 
low-level code without the tradeoffs typically associated with manual memory management. 
It’s a natural fit for Embedded Controller development—today and into the future.

Abstraction and normalization are key goals. OEMs often integrate components from multiple vendors and must adapt quickly 
when supply chains change. Rewriting integration logic for each vendor’s firmware is costly and error-prone.

By adopting ODP’s patterns, only the HAL layer typically needs to be updated when switching hardware components. 
The higher-level logic—what the system does with the component—remains unchanged

Instead, if the ODP patterns have been adopted, all that really needs to change is the HAL mapping layers that describe how the hardware action and data signals are defined 
and the higher-level business logic of handling that component can remain the same.

ODP is independent of any runtime or RTOS dependency.  Asynchronous support is provided by packages such as 
the [Embassy](https://embassy.dev/) framework for embedded systems. 
Embassy provides key building blocks like Hardware Abstraction Layers (HALs), consistent timing models, and support for both asynchronous and blocking execution modes.

### So how does this work?

A Rust crate defines the component behavior by implementing hardware pin traits provided by the target microcontroller's HAL 
(possibly via Embassy or a compatible interface). These traits are optionally normalized to [ACPI](https://en.wikipedia.org/wiki/ACPI) (Advanced Configuration and 
Power Interface) and ASL (ACPI Source Language) standards to align with common host-side expectations.

From there, the system moves into a familiar abstraction pattern. The HAL exposes actions on those pins 
(such as read() or write()), and the service logic builds higher-level operations (like read_temperature() or set_fan_speed(x)) 
using those primitives.

```mermaid
flowchart LR
Controller(Controller) --> PinTrait(Pin Traits) --> ASL(ASL) --> HAL(HAL interface) --> Fun(Functional Interface) --> Code(Code action)
style Controller fill:#8C8
style PinTrait fill:#8C8
```

In the case of a controller being switched out, assuming both controllers perform the same basic
functionality (e.g. read temperature, set fan speed) only the pin traits specific to the controller
likely need to be changed to implement with similar behavior. 
