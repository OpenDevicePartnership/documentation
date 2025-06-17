# Legacy EC Interface

ACPI specification has a definition for an embedded controller, however
this implementation is tied very closely to the eSPI bus and x86
architecture.

The following is an example of legacy EC interface definition from ACPI

[11.7. Thermal Zone Examples — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/11_Thermal_Management/thermal-zone-examples.html)

```rust
Scope(\\_SB.PCI0.ISA0) {
  Device(EC0) {
    Name(_HID, EISAID("PNP0C09")) // ID for this EC

    // current resource description for this EC
    Name(_CRS, ResourceTemplate() {
      IO(Decode16,0x62,0x62,0,1)
      IO(Decode16,0x66,0x66,0,1)
    })

    Name(_GPE, 0) // GPE index for this EC
    
    // create EC's region and field for thermal support
    OperationRegion(EC0, EmbeddedControl, 0, 0xFF)
    Field(EC0, ByteAcc, Lock, Preserve) {
      MODE, 1, // thermal policy (quiet/perform)
      FAN, 1, // fan power (on/off)
      , 6, // reserved
      TMP, 16, // current temp
      AC0, 16, // active cooling temp (fan high)
      , 16, // reserved
      PSV, 16, // passive cooling temp
      HOT 16, // critical S4 temp
      CRT, 16 // critical temp
    }

    // following is a method that OSPM will schedule after
    // it receives an SCI and queries the EC to receive value 7
    Method(_Q07) {
      Notify (\\_SB.PCI0.ISA0.EC0.TZ0, 0x80)
    } // end of Notify method

    // fan cooling on/off - engaged at AC0 temp
    PowerResource(PFAN, 0, 0) {
      Method(_STA) { Return (\\_SB.PCI0.ISA0.EC0.FAN) } // check power state
      Method(_ON) { Store (One, \\\\_SB.PCI0.ISA0.EC0.FAN) } // turn on fan
      Method(_OFF) { Store ( Zero, \\\\_SB.PCI0.ISA0.EC0.FAN) }// turn off
fan
    }

    // Create FAN device object
    Device (FAN) {
    // Device ID for the FAN
    Name(_HID, EISAID("PNP0C0B"))
    // list power resource for the fan
    Name(_PR0, Package(){PFAN})
    }

    // create a thermal zone
    ThermalZone (TZ0) {
      Method(_TMP) { Return (\\_SB.PCI0.ISA0.EC0.TMP )} // get current temp
      Method(_AC0) { Return (\\_SB.PCI0.ISA0.EC0.AC0) } // fan high temp
      Name(_AL0, Package(){\\_SB.PCI0.ISA0.EC0.FAN}) // fan is act cool dev
      Method(_PSV) { Return (\\_SB.PCI0.ISA0.EC0.PSV) } // passive cooling
temp
      Name(_PSL, Package (){\\_SB.CPU0}) // passive cooling devices
      Method(_HOT) { Return (\\_SB.PCI0.ISA0.EC0.HOT) } // get critical S4
temp
      Method(_CRT) { Return (\\_SB.PCI0.ISA0.EC0.CRT) } // get critical temp
      Method(_SCP, 1) { Store (Arg1, \\\\_SB.PCI0.ISA0.EC0.MODE) } // set
cooling mode

      Name(_TSP, 150) // passive sampling = 15 sec
      Name(_TZP, 0) // polling not required
      Name (_STR, Unicode ("System thermal zone"))
    } // end of TZ0
  } // end of ECO
} // end of \\\\_SB.PCI0.ISA0 scope-
```

On platforms that do not support IO port access there is an option to
define MMIO regions to simulate the IO port transactions.

In the above example you can see that the operation region directly maps
to features on the EC and you can change the EC behavior by writing to a
byte in the region or reading the latest data from the EC.

For a system with the EC connected via eSPI and that needs a simple
non-secure interface to the EC the above mapping works very well and
keeps the code simple. The eSPI protocol itself has details on port
accesses and uses the peripheral channel to easily read/write memory
mapped regions.

As the EC features evolve there are several requirements that do no work
well with this interface:

  - Different buses such as I3C, SPI, UART target a packet
    request/response rather than a memory mapped interface

  - Protected or restricted access and validation of request/response

  - Firmware update, large data driven requests that require larger data
    response the 256-byte region is limited

  - Discoverability of features available and OEM customizations

  - Out of order completion of requests, concurrency, routing and
    priority handling

As we try to address these limitations and move to a more packet based
protocol described in this document. The following section covers
details on how to adopt existing operation region to new ACPI
functionality.

## Adopting EC Operation Region

The new OS frameworks such as MPTF still use ACPI methods as primary
interface. Instead of defining devices such as FAN or ThermalZone in the
EC region you can simply define the EC region itself and then map all
the other ACPI functions to operate on this region. This will allow you
to maintain backwards compatibility with existing EC definitions.

```rust
Device(EC0) {
  Name(_HID, EISAID("PNP0C09")) // ID for this EC
  // current resource description for this EC
  Name(_CRS, ResourceTemplate() {
    IO(Decode16,0x62,0x62,0,1)
    IO(Decode16,0x66,0x66,0,1)
  })

  // create EC's region and field for thermal support
  OperationRegion(EC0, EmbeddedControl, 0, 0xFF)
  Field(EC0, ByteAcc, Lock, Preserve) {
    MODE, 1, // thermal policy (quiet/perform)
    FAN, 1, // fan power (on/off)
    , 6, // reserved
    TMP, 16, // current temp
    AC0, 16, // active cooling temp (fan high)
    , 16, // reserved
    PSV, 16, // passive cooling temp
    HOT 16, // critical S4 temp
    CRT, 16 // critical temp
  }
}

Device(SKIN) {
  Name(_HID, "MSFT000A") // New MPTF HID Temperature Device
  Method(_TMP, 0x0, Serialized) {
      Return( \\_SB.PCI0.ISA0.EC0.TMP)
  }
}
```

For more complicated functions that take a package some of the data may
be constructed within ACPI and some of the data pulled from the
OperationRegion. For example BIX for battery information may have a
combination of static and dynamic data like this:

```rust
Method (_BIX) {
  Name (BAT0, Package (0x12)
  {
    0x01, // Revision
    0x02, // Power Unit
    0x03, // Design Capacity
    \\_SB.PCI0.ISA0.EC0.BFCC, // Last Full Charge Capacity
    0x05, // Battery Technology
    0x06, // Design Voltage
    0x07, // Design capacity of Warning
    0x08, // Design Capacity of Low
    \\_SB.PCI0.ISA0.EC0.BCYL, // Cycle Count
    0x0A, // Measurement Accuracy
    0x0B, // Max Sampling Time
    0x0C, // Min Sampling Time
    0x0D, // Max Averaging Interval
    0x0E, // Min Averaging Interval
    0x0F, // Battery Capacity Granularity 1
    0x10, // Battery Capacity Granularity 2
    "Model123", // Model Number
    "Serial456", // Serial Number
    "Li-Ion", // Battery Type
    "OEMName" // OEM Information
  })
  Return(BAT0)
}
```

## Limitations for using Legacy EC

Before using the Legacy EC definition OEM’s should be aware of several
use cases that may limit you ability to use it.

### ACPI support for eSPI master

In the case of Legacy EC the communication to the EC is accomplished
directly by the ACPI driver using PORT IO and eSPI Peripheral Bus
commands. On ARM platforms there is no PORT IO and these must be
substituted with MMIO regions. The ACPI driver needs changes to support
MMIO which is being evaluated and support is not yet available. Some
Silicon Vendors also do not implement the full eSPI specification and as
such the ACPI driver cannot handle all the communication needs. On these
platforms using Legacy EC interface is not an option.

### Security of eSPI bus

When non-secure world is given access to the eSPI bus it can send
commands to device on that bus. Some HW designs have the TPM or SPINOR
on the same physical bus as the EC. On these designs allowing non-secure
world to directly sends commands to EC can break the security
requirements of other devices on the bus. In these cases the eSPI
communication must be done in the secure world over FF-A as covered in
this document and not use the Legacy EC channel. Since non-secure world
has complete access to the EC operation region there is no chance for
encryption of data. All data in the operation region is considered
non-secure.

### Functional limitations of Legacy EC

The peripheral region that is mapped in the Legacy EC in ACPI is limited
to 256 bytes and notification events to the ones that are defined and
handled in ACPI driver. To create custom solutions, send large packets
or support encryption of data the Legacy EC interface has limitations in
this area.

