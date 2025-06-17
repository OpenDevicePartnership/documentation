### ODP Resources for UEFI

For traditional UEFI development, an SDK called __EDK II__ is often used to supply much of the common functionality.

However, the __EDK II__ presumes the use of C, and ODP is seeking to replace this potentially insecure code base with Rust for future devices.

ODP features a subproject body of code that represents the elements one might traditionally find within the EDK II, but designed for  Rust. 

The official documentation for the Patina track of ODP can be found here:

[Official Patina Documentation](https://sturdy-adventure-nv32gqw.pages.github.io/)

This document covers 
- How to use materials from and contribute to the Open Device Partnership
- Development tools you will need, including Rust and other supporting tools
- Platform configuration and comparisons to EDK II (which may be familar to experienced UEFI developers)
- Coding patterns and standards
- Dependencies
- Industry background and current state assessments

### How Patina compares to traditional UEFI approaches

There are differences in the ODP approach here in a few areas.  For example, one significant departure is that in ODP there is no traditional SMM (System Management Mode).

SMM is a special-purpose operating mode provided by x86 CPUs (and compatible architectures) for executing highly privileged system-level code, independently of the operating system.

- It is triggered by a System Management Interrupt (SMI).

- Code running in SMM has full control over the system, including memory, I/O, and other hardware.

- It is isolated: the OS (and even hypervisors) cannot access or interfere with SMM execution or memory (SMRAM).

This may seem more than a little significant at first because SMM is used in key EDK II contexts, including:

- SmmCore
- SmmDriver
- SmmCommunication
- SmmVariable

But there is good reason for this omission:

Traditional SMM is not supported to prevent coupling between the DXE and MM environments. This exclusion extends to so-called 'combined' DXE modules also. 
These patterns are error-prone, increase DXE module complexity, and elevate the risk of security vulnerabilities.

Standalone MM should be used instead. The combined drivers have not gained traction in actual implementations due to their lack of compatibility for most practical purposes and further increase the likelihood of coupling between core environments and user error when authoring those modules. The Rust DXE Core focuses on modern use cases and simplification of the overall DXE environment.

### What's Next?
In upcoming sections we'll explore how Patina components interact within the DXE Core, how to define UEFI services in Rust, and how to develop real-world DXE drivers using ODP tools. First, we are going to discuss the role of ODP in an Embedded Controller context.  If you are not interested in the EC side of things, you may want to jump directly to the Patina material from the [ODP tracks](../../tracks.md) section.

