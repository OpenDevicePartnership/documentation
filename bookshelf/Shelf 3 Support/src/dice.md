# DICE

"DICE is a hardware Root-of-Trust (RoT) used to protect the devices and components where a TPM would be impractical or infeasible. When a TPM is present, DICE is used to protect communication with the TPM and provides the Root of Trust for Measurement (RTM) for the platform. DICE was designed to close critical gaps in infrastructure and help to establish safeguarding measures for devices. The DICE RoT can also be easily integrated into existing infrastructure, with the architecture being flexible and interoperable with existing security standards."

DICE (Device Identifier Composition Engine) specifies a hardware Root-of-Trust (RoT) scheme designed to secure the firmware for devices and components in a system where a Trusted Partition Manager (TPM) may not be available, and/or to protect the TPM if it does exist.

Essentially, DICE is used to validate firmware through digital signatures and similar crytographic mechanisms. This prevents unsanctioned firmware updates to be applied or executed.

The DICE specification is not the _only_ way in which a system may be able to validate and secure it's firmware, but it is a proven and certified approach.

While there is no Rust crate that implements this per-se, there are certainly core cryptographic libraries available that can be used to implement the specification. 

[Return to Library](../../library.html)
