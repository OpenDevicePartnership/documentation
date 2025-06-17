# How To Build A Modern Laptop using ODP

This section will present a series of practical examples for creating ODP components for the embedded controller using a commodity-level development board to serve as an ersatz MCU SoC, and implementing a Patina DXE Core and bootloader to start up an operating system on a QEMU host that communicates with the EC. This is done through a series of practical exercises that stand alone as development examples, and come together in the end to create a credible, working integration.  

These exercises will:
- build components for the embedded controller
    - battery, charger and power policy
    - thermal and sensors
    - connectivity
    - security architectures
- build components for the DXE Core
    - example component
    - firmware security
    - EC coordination
- integrate the components into a system
    - set up QEMU as a virtual host
    - use Patina firmware to boot this virtual host into Windows
    - coordinate between the boot firmware and the embedded controller
    - use runtime services to interact with EC services
    - implement and explore security firmware and architectures




