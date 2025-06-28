# Battery Service

Battery control is monitored through the Modern Power Thermal Framework
(MPTF). See this specification for further details on implementing
firmware for these features. This section outlines the interface
required in ACPI for this framework to function.

<b>Note:</b> There is an issue with ACPI and embedded packages `return Package() {BST0,BST1,BST2,BST3}` returns "BST0","BST1","BST2","BST3" rather than the values pointed to by these variables. As such we need to create a global Name for BSTD and initialize default values and update these fields like the following.

```
  Name (BSTD, Package (4) {
    0x2,
    0x500,
    0x10000,
    0x3C28
  })
...
  BSTD[0] = BST0
  BSTD[1] = BST1
  BSTD[2] = BST2
  BSTD[3] = BST3
  Return(BSTD)
```

| Command                 | Description                                                                                                                                     |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| EC_BAT_GET_BIX = 0x1 | Returns information about battery, model, serial number voltage. Note this is a superset of BIF. (MPTF)                                         |
| EC_BAT_GET_BST = 0x2 | Get Battery Status, must also have notify event on state change. (MPTF)                                                                         |
| EC_BAT_GET_PSR = 0x3 | Returns whether this power source device is currently online. (MPTF)                                                                            |
| EC_BAT_GET_PIF = 0x4 | Returns static information about a power source. (MPTF)                                                                                         |
| EC_BAT_GET_BPS = 0x5 | Power delivery capabilities of battery at present time. (MPTF)                                                                                  |
| EC_BAT_SET_BTP = 0x6 | Set battery trip point to generate SCI event (MPTF)                                                                                             |
| EC_BAT_SET_BPT = 0x7 | Set Battery Power Threshold (MPTF)                                                                                                              |
| EC_BAT_GET_BPC = 0x8 | Returns static variables that are associated with system power characteristics on the battery path and power threshold support settings. (MPTF) |
| EC_BAT_SET_BMC= 0x9  | Battery Maintenance Control                                                                                                                     |
| EC_BAT_GET_BMD = 0xA | Returns battery information regarding charging and calibration                                                                                  |
| EC_BAT_GET_BCT = 0xB | Returns battery charge time.                                                                                                                    |
| EC_BAT_GET_BTM = 0xC | Get estimated runtime of battery while discharging                                                                                              |
| EC_BAT_SET_BMS = 0xD | Sets battery capacity sampling time in ms                                                                                                       |
| EC_BAT_SET_BMA = 0xE | Battery Measurement Average Interval                                                                                                            |
| EC_BAT_GET_STA = 0xF | Get battery availability                                                                                                                        |

## EC_BAT_GET_BIX

Returns information about battery, model, serial number voltage etc

### Input Parameters

None

### Output Parameters

Should return structure as defined by ACPI specification

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#bix-battery-information-extended)

### FFA ACPI Example
```
  Name (BIXD, Package(21) {
    0,
    0,
    0x15F90,
    0x15F90,
    1,
    0x3C28,
    0x8F,
    0xE10,
    1,
    0x17318,
    0x03E8,
    0x03E8,
    0x03E8,
    0x03E8,
    0x380,
    0xE1,
    "        ",
    "        ",
    "        ",
    "        ",
    0
  })

  Method (_BIX, 0, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,32,BIX0)  // Out – Revision
      CreateDwordField(BUFF,36,BIX1)  // Out – Power Unit
      CreateDwordField(BUFF,40,BIX2)  // Out – Design Capacity
      CreateDwordField(BUFF,44,BIX3)  // Out – Last Full Charge Capacity
      CreateDwordField(BUFF,48,BIX4)  // Out – Battery Technology
      CreateDwordField(BUFF,52,BIX5)  // Out – Design Voltage
      CreateDwordField(BUFF,56,BIX6)  // Out – Design Capacity of Warning
      CreateDwordField(BUFF,60,BIX7)  // Out – Design Capacity of Low
      CreateDwordField(BUFF,64,BIX8)  // Out – Cycle Count
      CreateDwordField(BUFF,68,BIX9)  // Out – Measurement Accuracy
      CreateDwordField(BUFF,72,BI10)  // Out – Max Sampling Time
      CreateDwordField(BUFF,76,BI11)  // Out – Min Sampling Time
      CreateDwordField(BUFF,80,BI12)  // Out – Max Averaging Internal
      CreateDwordField(BUFF,84,BI13)  // Out – Min Averaging Interval
      CreateDwordField(BUFF,88,BI14)  // Out – Battery Capacity Granularity 1
      CreateDwordField(BUFF,92,BI15)  // Out – Battery Capacity Granularity 2
      CreateField(BUFF,768,64,BI16)  // Out – Model Number
      CreateField(BUFF,832,64,BI17)  // Out – Serial number
      CreateField(BUFF,896,64,BI18)  // Out – Battery Type
      CreateField(BUFF,960,64,BI19)  // Out – OEM Information
      CreateDwordField(BUFF,128,BI20)  // Out – OEM Information

      Store(0x1, CMDD) //EC_BAT_GET_BIX
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        BIXD[0] = BIX0
        BIXD[1] = BIX1
        BIXD[2] = BIX2
        BIXD[3] = BIX3
        BIXD[4] = BIX4
        BIXD[5] = BIX5
        BIXD[6] = BIX6
        BIXD[7] = BIX7
        BIXD[8] = BIX8
        BIXD[9] = BIX9
        BIXD[10] = BI10
        BIXD[11] = BI11
        BIXD[12] = BI12
        BIXD[13] = BI13
        BIXD[14] = BI14
        BIXD[15] = BI15
        BIXD[16] = BI16
        BIXD[17] = BI17
        BIXD[18] = BI18
        BIXD[19] = BI19
        BIXD[20] = BI20
      }
    }
    Return(BIXD)
  }
  ```

## EC_BAT_GET_BST

This object returns the present battery status. Whenever the Battery
State value changes, the system will generate an SCI to notify the OS.

### Input Parameters

None

### Output Parameters

Should return structure as defined by ACPI specification

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#bst-battery-status)

### FFA ACPI Example

```
  Name (BSTD, Package (4) {
    0x2,
    0x500,
    0x10000,
    0x3C28
  })

  Method (_BST, 0, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,32,BST0)  // Out – Battery State DWord
      CreateDwordField(BUFF,36,BST1)  // Out – Battery Rate DWord
      CreateDwordField(BUFF,40,BST2)  // Out – Battery Reamining Capacity DWord
      CreateDwordField(BUFF,44,BST3)  // Out – Battery Voltage DWord

      Store(0x2, CMDD) //EC_BAT_GET_BST
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        BSTD[0] = BST0
        BSTD[1] = BST1
        BSTD[2] = BST2
        BSTD[3] = BST3
      }
    }
    Return(BSTD)
  }
```

## EC_BAT_GET_PSR

Returns whether the power source device is currently in use. This can be
used to determine if system is running off this power supply or adapter.
On mobile systes this will report that the system is not running on the
AC adapter if any of the batteries in the system is being forced to
discharge. In systems that contains multiple power sources, this object
reports the power source’s online or offline status.

### Input Parameters

None

### Output Parameters

Should return structure as defined by ACPI specification

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#battery-control-methods)

### FFA ACPI Example

```
  Method (_PSR, 0, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,32,PSR0)  // Out – Power Source

      Store(0x3, CMDD) //EC_BAT_GET_PSR
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        return(PSR0)
      }
    }

    Return(0)
  }
```
## EC_BAT_GET_PIF

This object returns information about the Power Source, which remains
constant until the Power Source is changed. When the power source
changes, the platform issues a Notify(0x0) (Bus Check) to the Power
Source device to indicate that OSPM must re-evaluate the _PIF object.

### Input Parameters

None

### Output Parameters

Should return structure as defined by ACPI specification

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#pif-power-source-information)

### FFA ACPI Example
```
  Name( PIFD, Package(6) {
    0,          // Out – Power Source State
    0,          // Out – Maximum Output Power
    0,          // Out – Maximum Input Power
    "        ", // Out – Model Number
    "        ", // Out – Serial Number
    "        "  // Out – OEM Information
  })

  Method (_PIF, 0, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,32,PIF0)  // Out – Power Source State
      CreateDwordField(BUFF,36,PIF1)  // Out – Maximum Output Power
      CreateDwordField(BUFF,40,PIF2)  // Out – Maximum Input Power
      CreateField(BUFF,352,64,PIF3)  // Out – Model Number
      CreateField(BUFF,416,64,PIF4)  // Out – Serial Number
      CreateField(BUFF,480,64,PIF5)  // Out – OEM Information

      Store(0x4, CMDD) //EC_BAT_GET_PIF
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        PIFD[0] = PIF0
        PIFD[1] = PIF1
        PIFD[2] = PIF2
        PIFD[3] = PIF3
        PIFD[4] = PIF4
        PIFD[5] = PIF5

      }
    }

    Return(PIFD)
  }
```

## EC_BAT_GET_BPS

This optional object returns the power delivery capabilities of the
battery at the present time. If multiple batteries are present within
the system, the sum of peak power levels from each battery can be used
to determine the total available power.

### Input Parameters

None

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example

```
  Name( BPSD, Package(5) {
    0,  // Out – Revision
    0,  // Out – Instantaneous Peak Power Level
    0,  // Out – Instantaneous Peak Power Period
    0,  // Out – Sustainable Peak Power Level
    0  // Out – Sustainable Peak Power Period
  })

  Method (_BPS, 0, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,32,BPS0)  // Out – Revision
      CreateDwordField(BUFF,36,BPS1)  // Out – Instantaneous Peak Power Level
      CreateDwordField(BUFF,40,BPS2)  // Out – Instantaneous Peak Power Period
      CreateDwordField(BUFF,44,BPS3)  // Out – Sustainable Peak Power Level
      CreateDwordField(BUFF,48,BPS4)  // Out – Sustainable Peak Power Period

      Store(0x5, CMDD) //EC_BAT_GET_BPS
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        BPSD[0] = BPS0
        BPSD[1] = BPS1
        BPSD[2] = BPS2
        BPSD[3] = BPS3
        BPSD[4] = BPS4
      }
    }
    Return(BPSD)
  }
```

## EC_BAT_SET_BTP

This object is used to set a trip point to generate an SCI whenever the
Battery Remaining Capacity reaches or crosses the value specified in the
_BTP object. Required on systems supporting Modern Standby

[Platform design for modern standby | Microsoft
Learn](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/platform-design-for-modern-standby)

### Input Parameters

See ACPI documentation for details

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#btp-battery-trip-point)

### Output Parameters

None

### FFA ACPI Example
```
  Method (_BTP, 1, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,36,BTP0)  // In - Trip point value

      Store(0x6, CMDD) //EC_BAT_SET_BTP
      Store(Arg0, BTP0)
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        return(Zero )
      }
    }
    Return(Zero)
  }
```

## EC_BAT_GET_BPC

This optional object returns static values that are used to configure
power threshold support in the platform firmware. OSPM can use the
information to determine the capabilities of power delivery and
threshold support for each battery in the system.

### Input Parameters

None

### Output Parameters

Should return structure as defined by ACPI specification

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#bpc-battery-power-characteristics)

### FFA ACPI Example
```
  Name( BPCD, Package(4) {
    1,  // Out - Revision
    0,  // Out - Threshold support
    8000,  // Out - Max Inst peak power
    2000  // Out - Max Sust peak power
  })

  Method (_BPC, 0, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,32,BPC0)  // Out - Revision
      CreateDwordField(BUFF,36,BPC1)  // Out - Threshold support
      CreateDwordField(BUFF,40,BPC2)  // Out - Max Inst peak power
      CreateDwordField(BUFF,44,BPC3)  // Out - Max Sust peak power

      Store(0x8, CMDD) //EC_BAT_GET_BPC
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        BPCD[0] = BPC0
        BPCD[1] = BPC1
        BPCD[2] = BPC2
        BPCD[3] = BPC3
      }
    }
    Return(BPCD)
  }
```
## EC_BAT_SET_BPT

his optional object may be present under a battery device. OSPM must
read _BPC first to determine the power delivery capability threshold
support in the platform firmware and invoke this Method in order to
program the threshold accordingly. If the platform does not support
battery peak power thresholds, this Method should not be included in the
namespace.

### Input Parameters

See ACPI specification for input parameters

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#bpt-battery-power-threshold)

### Output Parameters

Should return structure as defined by ACPI specification

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#bpt-battery-power-threshold)

### FFA ACPI Example
```
  Method (_BPT, 3, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,36,BPT0)  // In - Revision
      CreateDwordField(BUFF,40,BPT1)  // In - Threshold ID
      CreateDwordField(BUFF,44,BPT2)  // In - Threshold value
      CreateDwordField(BUFF,32,BPTS)  // Out - Trip point value

      Store(0x7, CMDD) //EC_BAT_SET_BPT
      Store(Arg0, BPT0)
      Store(Arg1, BPT1)
      Store(Arg2, BPT2)
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        return(BPTS)
      }
    }
    Return(Zero)
  }
```

## EC_BAT_SET_BMC

This object is used to initiate calibration cycles or to control the
charger and whether or not a battery is powering the system. This object
is only present under a battery device if the _BMD Capabilities Flags
field has bit 0, 1, 2, or 5 set.

### Input Parameters

See ACPI specification for input parameter definition

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#bmc-battery-maintenance-control)

### Output Parameters

None

### FFA ACPI Example

```
  Method (_BMC, 1, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,36,BMC0)  // In - Feature control flags

      Store(0x9, CMDD) //EC_BAT_SET_BMC
      Store(Arg0, BMC0)
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    }
    Return(Zero)
  }
```

## EC_BAT_GET_BMD

This optional object returns information about the battery’s
capabilities and current state in relation to battery calibration and
charger control features. If the _BMC object (defined below) is present
under a battery device, this object must also be present. Whenever the
Status Flags value changes, AML code will issue a
Notify(battery_device, 0x82). In addition, AML will issue a
Notify(battery_device, 0x82) if evaluating _BMC did not result in
causing the Status Flags to be set as indicated in that argument to
_BMC. AML is not required to issue Notify(battery_device, 0x82) if the
Status Flags change while evaluating _BMC unless the change does not
correspond to the argument passed to _BMC.

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#bmd-battery-maintenance-data)

### Input Parameters

None

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example
```
  Name( BMDD, Package(5) {
    0,  // Out - Status
    0,  // Out - Capability Flags
    0,  // Out - Recalibrate count
    0,  // Out - Quick recal time
    0 // Out - Slow recal time
  })
  
  Method (_BMD, 0, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,32,BMD0)  // Out - Status
      CreateDwordField(BUFF,36,BMD1)  // Out - Capability Flags
      CreateDwordField(BUFF,40,BMD2)  // Out - Recalibrate count
      CreateDwordField(BUFF,44,BMD3)  // Out - Quick recal time
      CreateDwordField(BUFF,48,BMD4)  // Out - Slow recal time

      Store(0xa, CMDD) //EC_BAT_GET_BMD
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        BMDD[0] = BMD0
        BMDD[1] = BMD1
        BMDD[2] = BMD2
        BMDD[3] = BMD3
        BMDD[4] = BMD4
      }
    }
    Return(BMDD)
  }
```
## EC_BAT_GET_BCT

When the battery is charging, this optional object returns the estimated
time from present to when it is charged to a given percentage of Last
Full Charge Capacity.

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#bct-battery-charge-time)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example
```
  Method (_BCT, 1, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,36,BCT0)  // In - ChargeLevel
      CreateDwordField(BUFF,32,BCTD)  // Out - Result

      Store(0xb, CMDD) //EC_BAT_GET_BCT
      Store(Arg0, BCT0)
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        return(BCTD)
      }
    }
    Return(Zero)
  }
```

## EC_BAT_GET_BTM

This optional object returns the estimated runtime of the battery while
it is discharging.

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#btm-battery-time)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

## EC_BAT_SET_BMS

This object is used to set the sampling time of the battery capacity
measurement, in milliseconds.

The Sampling Time is the duration between two consecutive measurements
of the battery’s capacities specified in _BST, such as present rate and
remaining capacity. If the OSPM makes two succeeding readings through
_BST beyond the duration, two different results will be returned.

The OSPM may read the Max Sampling Time and Min Sampling Time with _BIX
during boot time, and set a specific sampling time within the range with
_BMS.

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#bms-battery-measurement-sampling-time)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example

```
  Method (_BMS, 1, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,36,BMS0)  // In - Sampling Time
      CreateDwordField(BUFF,32,BMSD)  // Out - Result code

      Store(0xd, CMDD) //EC_BAT_SET_BMS
      Store(Arg0, BMS0)
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        return(BMSD)
      }
    }
    Return(Zero)
  }
```

## EC_BAT_SET_BMA

This object is used to set the averaging interval of the battery
capacity measurement, in milliseconds. The Battery Measurement Averaging
Interval is the length of time within which the battery averages the
capacity measurements specified in _BST, such as remaining capacity and
present rate.

The OSPM may read the Max Average Interval and Min Average Interval with
_BIX during boot time, and set a specific average interval within the
range with _BMA.

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/10_Power_Source_and_Power_Meter_Devices/Power_Source_and_Power_Meter_Devices.html#bma-battery-measurement-averaging-interval)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example
```
  Method (_BMA, 1, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,36,BMA0)  // In - Averaging Interval
      CreateDwordField(BUFF,32,BMAD)  // Out - Result code

      Store(0xe, CMDD) //EC_BAT_SET_BMA
      Store(Arg0, BMA0)
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        return(BMAD)
      }
    }
    Return(Zero)
  }
```

## EC_BAT_GET_STA

Returns battery status to the OS along with any error conditions as defined by ACPI specification.

### Input Parameters

None

### Output Parameters

Should return structure as defined by ACPI specification

[10. Power Source and Power Meter Devices — ACPI Specification 6.4
documentation](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/06_Device_Configuration/Device_Configuration.html#sta-device-status)

### FFA ACPI Example
```
  Method (BSTA, 0, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,32,STAD)  // Out - Battery supported info

      Store(0xf, CMDD) //EC_BAT_GET_STA
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        return(STAD)
      }
    }
    Return(Zero)
  }
```

