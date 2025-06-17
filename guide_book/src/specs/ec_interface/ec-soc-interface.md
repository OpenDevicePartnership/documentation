# EC SOC Interface

## EC Physical Interface

The interface by which the EC is physically wired to the SOC may vary
depending on what interfaces are supported by the Silicon Vendor, EC
manufacturer and OEM. It is recommended that a simple and low latency
protocol is chosen such as eSPI, I3C, UART, memory.

## EC Software Interface

There are several existing OS interfaces that exist today via ACPI and
HID to manage thermal, battery, keyboard, touch etc. These existing
structures need to keep working and any new interface must be created in
such a way that it does not break existing interfaces. This document
covers details on how to implement EC services in secure world and keep
compatibility with non-secure EC OperationRegions. It is important to
work towards a more robust solution that will handle routing, larger
packets and security in a common way across OS’s and across SV
architectures. 

![EC connections to apps](media/odp_arch.png)