# Creating a Virtual Laptop

What would it take to create a virtual laptop—a system that feels like a real platform, but is built entirely from emulated pieces?

This is an ambitious goal, but it’s a natural culmination of the topics we’ve covered. By combining a virtualized __Embedded Controller (EC)__, a __Patina__ boot firmware layer, and an emulated host environment, we can build a system that exercises nearly the same firmware flows as real hardware. 

## Step 1: Build an EC
The heart of any modern laptop design is the Embedded Controller. Our first step is to build one using ODP components:

- __Option A: Building onto a development board.__
 - If you are able to source a SOC development board with all the necessary component hardware -- then great!
 - If this is hard to come by, you could use a commodity development board and implement simulated components, as we have done in the examples in this guide.  Although there would not be any real hardware action, the logical behaviors would be the same and the virtual laptop would operate the same way.
 - __Option B: Virtualized microcontroller__
 Similar to Option A, but instead of a commodity board, you build into a virtual container that emulates a popular microcontroller.  This makes the “virtual laptop” self-contained, since the EC never leaves your development workstation.

 In either case, the EC hosts the _battery_, _charger_, and _thermal_ components we've already worked through.

 ## Step 2: Implement Components
 Populate the EC with the devices you want to model:
- Real hardware drivers if you’re on a development board.
- Simulated components (battery, charger, fan, sensors) if you’re inside an emulator.

Our exercises have already shown how to create simulated behavior loops—charging, thermal rise/cooling, and fan response—that are realistic enough to validate integration.

## Step 3: Create an ACPI Bus Interface
For the host OS to communicate with the EC, we need a standard interface. The most common is ACPI EC op-region access.
- Define the ACPI tables that expose your EC’s registers and events.
- Implement a transport bridge from your virtualized EC into QEMU’s ACPI bus model.

This is similar in spirit to the [MPTF demo](../how/ec/thermal/mptf/mptf.md), which shows how thermal information can flow through ACPI.

At this point, the EC is no longer a stand-alone curiosity — it is visible to the host as part of the platform.

## Step 4: Exercise the EC from the Host
With ACPI wired up, you can use the EC Test App to drive your virtual EC just as you would on physical hardware:
- Send queries for battery and thermal state.
- Trigger events like charger attach/detach.
- Validate that your policy responses are consistent.

We've mentioned the [ODP ec-test-app](https://github.com/OpenDevicePartnership/ec-test-app) before.  This would be a great place
to use it.

This is where the line between “virtual” and “real” blurs: the host doesn’t care whether the EC is simulated or silicon, it simply sees ACPI.

## Step 5: Add a Patina Boot Layer
Next, layer in the host firmware:

- Follow the [Patina](../architecture/patina_framework.md) resources online to build a Patina DXE Core image 
- Add only the minimal DXE components needed to initialize ACPI and speak to the EC.

This gives your virtual laptop a complete boot firmware stage.

## Step 6: Host on QEMU
Run the system inside QEMU:
- QEMU emulates the chipset and host devices (disk, network, display).
- Your Patina firmware binary is loaded as the platform BIOS.
- Your EC (real or emulated) is connected through the ACPI interface.

At this point, you have an emulated platform with both host firmware and an EC.

## Step 7: Boot into an OS
Finally, boot into a minimal Windows (or Linux) environment:
- Use ACPI to discover and communicate with the EC.
- Run demo or sample apps that show the EC integration (battery life reporting, thermal throttling, charger state).

Validate your end-to-end firmware story _without ever touching a soldering iron!_

> --------
> ### Why attempt this?
> A virtual laptop project is audacious, but achievable. It combines the EC exercises we’ve built up in this guide with Patina firmware and QEMU emulation. The result is a reproducible platform where:
> - Firmware logic can be tested and demonstrated.
> - Policies can be exercised through ACPI.
> - OS-level apps can validate the end-to-end behavior.
>
> This is the closest you can get to a real laptop—without one sitting on your desk.
>
> ---------



