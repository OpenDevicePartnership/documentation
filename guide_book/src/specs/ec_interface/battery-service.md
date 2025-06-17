# Battery Service

Battery control is monitored through the Modern Power Thermal Framework
(MPTF). See this specification for further details on implementing
firmware for these features. This section outlines the interface
required in ACPI for this framework to function.

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
Method (_BIX) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(144){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,144,1088,BIXD) // Out – Raw data response max length

    Store(20, LENG)
    Store(0x1, CMDD) // EC_BAT_GET_BIX
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)


    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (BIXD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_BST) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(34){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,144,128,BSTD) // Out – Raw data response 4 DWords

    Store(20, LENG)
    Store(0x2, CMDD) // EC_BAT_GET_BST
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (BSTD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_PSR) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(22){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,144,32,PSRD) // Out – Raw data response (overlaps with CMDD)
    
    Store(20, LENG)
    Store(0x3, CMDD) // EC_BAT_GET_PSR
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (PSRD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_PIF) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(22){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,144,1088,PIFD) // Out – Raw data response (overlaps with CMDD)
    Store(20, LENG)
    Store(0x4, CMDD) // EC_BAT_GET_PIF
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (PIFD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_BPS) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(22){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,144,136,BPSD) // Out – BSP structure 5 integers

    Store(20, LENG)
    Store(0x5, CMDD) // EC_BAT_GET_BPS
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (BPSD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_BTP) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(24){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDWordField(BUFF,19, BTP1) // In – Battery Trip Point

    Store(20, LENG)
    Store(0x6, CMDD) // EC_BAT_SET_BTP
    Store(Arg0, BTP1)
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (One)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_BPC) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(24){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,19,128, BPCD) // Out – BPC output Data

    Store(20, LENG)
    Store(0x8, CMDD) // EC_BAT_GET_BPC
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (BPCD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_BPT) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(32){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDwordField(BUFF,19, BPT1) // In – Averaging Interval
    CreateDwordField(BUFF,23, BPT2) // In – Threshold ID
    CreateDwordField(BUFF,27, BPT3) // In – Threshold Value
    CreateField(BUFF,144,32,BPTD) // Out – BPT integer output

    Store(0x30, LENG)
    Store(0x7, CMDD) // EC_BAT_SET_BPT
    Store(Arg0,BPT1)
    Store(Arg1,BPT2)
    Store(Arg2,BPT3)
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (BPTD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_BMC) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(22){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDWordField(BUFF,19, BMCF) // In – Feature Control Flags

    Store(20, LENG)
    Store(0x9, CMDD) // EC_BAT_SET_BMC
    Store(Arg0,BMCF)
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (One)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_BMD) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(40){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,144,160,BMDD) // Out – BMD structure 5 DWords

    Store(20, LENG)
    Store(0xA, CMDD) // EC_BAT_GET_BMD
    Store(Arg0,BMCF)
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (BMDD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_BCT) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(22){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDWordField(BUFF,19, CHLV) // In – ChargeLevel
    CreateField(BUFF,144,32,BCTD) // Out – Raw data response (overlaps with CMDD)

    Store(20, LENG)
    Store(0xB, CMDD) // EC_BAT_GET_BCT
    Store(Arg0,CHLV)
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (BCTD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_BMS) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(32){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDwordField(BUFF,19, BMS1) // In – Sampling Time
    CreateField(BUFF,144,32,BMSD) // Out – BPT integer output

    Store(20, LENG)
    Store(0xD, CMDD) // EC_BAT_SET_BMS
    Store(Arg0,BMS1)
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (BMSD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_BMA) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(32){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDwordField(BUFF,19, BMA1) // In – Averaging Interval
    CreateField(BUFF,144,32,BMAD) // Out – BMA integer output
    
    Store(20, LENG)
    Store(0xE, CMDD) // EC_BAT_SET_BMA
    Store(Arg0,BMS1)
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (BMAD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
Method (_STA) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(144){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,144,32,STAD) // Out – Raw data with status

    Store(20, LENG)
    Store(0xF, CMDD) // EC_BAT_GET_STA
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)


    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (STAD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
}
```

