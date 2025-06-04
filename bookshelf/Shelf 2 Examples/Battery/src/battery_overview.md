# Battery and Power Management

This example shows how to implement a mock battery service as part of the Embedded Controller (EC) power management system.

In this sample, we are going to implement a complete battery service subsystem.

## Relevant Repositories

We don't need to reinvent any wheels here. The ODP resources include ample template code and examples we can refer to for such a task. It is useful to identify which repositories contain these resources:

### soc-embedded-controller

This repository provides the core EC functionality, which in this case is centered around power policy and regulation.

Although it includes integration code for an `imxrt` board, the repository is structured to make portability to other integrations relatively straightforward. We will refer to this often as we work on our own (virtual) battery service implementation.

We’ll begin with the battery service — one of the embedded services — and later return here to integrate our battery into the broader scope of power management.

### embedded-services

We've touched on this before in [Embedded Services](../embedded_services/index.html), where we examined a Thermal subsystem implementation and explored variations between secure ARM-based and legacy x86_64-based systems.

We'll return to both of these concepts later. For now, we’ll focus on implementing a Battery subsystem and related Power Policy services. After that, we’ll fold in Thermal support and revisit the secure vs. non-secure implementations.

### embedded-batteries

This repository defines the Hardware Abstraction Layer (HAL) for a battery, tailored to the specific IC hardware being targeted. It builds a layered API chain upward, making most of the code portable and reusable across different integrations.

---

### The Smart Battery

Batteries are ubiquitous in today’s portable devices. With many types of batteries serving various applications and provided by many vendors, the [Smart Battery Data Specification](https://sbs-forum.org/specs/sbdat110.pdf) offers a standard to normalize this diversity.

Published by the Smart Battery System Implementers Forum (SBS-IF), this specification defines both electrical characteristics and — more importantly for us — the data and communication semantics of battery state.

Let's explore how this specification informs our implementation.

#### Battery Information

A battery provides dynamic information (e.g., remaining charge), static metadata (e.g., make/model/serial/version), and operational parameters (e.g., recommended charge voltage/current).

As explored in [...](...), some of this information is exposed through direct hardware interfaces (e.g., GPIO or MMIO), while others originate from firmware logic or are derived dynamically.

Batteries typically report their state over a bus when queried and may also broadcast alarms when thresholds are breached.

The SBS specification outlines these functions that a smart battery should implement. These define a consistent set of data points and behaviors that other power management components can rely on:

- `ManufacturerAccess` – Optional, manufacturer-specific 16-bit value.
- `RemainingCapacityAlarm` – Battery capacity threshold at which an alert should be raised.
- `RemainingTimeAlarm` – Estimated time remaining before an alert should be raised.
- `BatteryMode` – Flags indicating operational states or supported features.
- `AtRate` – Charging/discharging rate used in subsequent time estimations.
- `AtRateTimeToFull` – Time to full charge at the given rate.
- `AtRateTimeToEmpty` – Time to depletion at the given rate.
- `AtRateTimeOK` – Whether the battery can sustain the given rate for at least 10 seconds.
- `Temperature` – Battery temperature.
- `Voltage` – Battery voltage.
- `Current` – Charge or discharge current.
- `AverageCurrent` – One-minute rolling average of current.
- `MaxError` – Expected error margin in charge calculations.
- `RelativeStateOfCharge` – % of full charge capacity remaining.
- `AbsoluteStateOfCharge` – % of design capacity remaining.
- `RemainingCapacity` – In mAh or Wh, based on a capacity mode flag.
- `FullChargeCapacity` – In mAh or Wh, based on capacity mode.
- `RunTimeToEmpty` – Estimated minutes remaining.
- `AverageTimeToEmpty` – One-minute average of minutes to empty.
- `AverageTimeToFull` – One-minute average of minutes to full charge.
- `BatteryStatus` – Flags indicating current state conditions.
-  `CycleCount` - Number of cycles (a measure of wear). A cycle is the amount of discharge approximately equal to the value of the DesignCapacity.
- `DesignCapacity` - The theoretical capacity of a new battery pack.
- `DesignVoltage` - The theoritical voltage of a new battery pack.
- `SpecificationInfo` - Version and scaling specification info
- `ManufactureDate` - The data of manufacture as a bit-packed integer
- `SerialNumber` - the manufacturer assigned serial number of this battery pack.
- `ManufacturerName` - Name of the manufacturer
- `DeviceName` - Name of battery model.
- `DeviceChemistry` - String defining the battery chemical type
- `ManufacturerData` - (optional) proprietary manufacturer data.

Please refer to the actual specification for details.  For example, functions referring to capacity may report in either current (mAh) or wattage (Wh) depending upon the current state of the CAPACITY_MODE flag (found in BatteryMode).

Some systems may support removable batteries, and such conditions must be accounted for in those designs.

---

## A Mock Battery

In our example, we will use a microcontroller board as our EC but will not focus on real battery or charger hardware at this stage.

This allows us to begin development without sourcing specific hardware while still implementing nearly all of the system’s behavior. In the end, we will have a fully functional—albeit artificial—battery subsystem.

Once complete, this mock can be replaced with hardware-specific IO bindings, without requiring changes to the higher-level system logic.

Next we will look at what resources in the ODP repositories we will be working with as we build our battery implementation.

<!--[Return to Library](../../Library.html) -->
