# How we will build the Battery Component


Like most components, the battery starts with a definition, or specification.  Most common components have industry-standard specifications associated with them.  For the battery, we have the Smart Battery Specification (SBS).

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

In the next steps, we will use the ODP published crates that expose this SBS defnition as a Trait and build our implementation on top of that starting point.

We will implement the mock values and behaviors of our simulated battery - instead of defining and building a HAL layer - 
and then we will walk through the process of attaching this component definition to a Device wrapper and registering it
as a component with a Controller that can be manipulated by a service layer - in this case, the Power Policy Service.


