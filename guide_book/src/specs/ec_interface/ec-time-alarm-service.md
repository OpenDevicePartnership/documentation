# EC Time Alarm Service

The following sections define the operation and definition of the
optional control method-based Time and Alarm device, which provides a
hardware independent abstraction and a more robust alternative to the
Real Time Clock (RTC)

ACPI specification details are in version 6.5 Chapter 9.

[9. ACPI-Defined Devices and Device-Specific Objects — ACPI
Specification 6.5 documentation
(uefi.org)](https://uefi.org/specs/ACPI/6.5/09_ACPI_Defined_Devices_and_Device_Specific_Objects.html#time-and-alarm-device)

| **Command**             | **Description**                                   |
| ----------------------- | ------------------------------------------------- |
| EC_TAS_GET_GCP = 0x1 | Get the capabilities of the time and alarm device |
| EC_TAS_GET_GRT = 0x2 | Get the Real Time                                 |
| EC_TAS_SET_SRT = 0x3 | Set the Real Time                                 |
| EC_TAS_GET_GWS = 0x4 | Get Wake Status                                   |
| EC_TAS_SET_CWS = 0x5 | Clear Wake Status                                 |
| EC_TAS_SET_STV = 0x6 | Set Timer value for given timer                   |
| EC_TAS_GET_TIV = 0x7 | Get Timer value remaining for given timer         |

## EC_TAS_GET_GCP

This object is required and provides the OSPM with a bit mask of the
device capabilities.

[9. ACPI-Defined Devices and Device-Specific Objects — ACPI
Specification 6.5
documentation](https://uefi.org/specs/ACPI/6.5/09_ACPI_Defined_Devices_and_Device_Specific_Objects.html#gcp-get-capability)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI 
```
Method (_GCP) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(32){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,144,32,GCPD) // Out – 32-bit integer described above
  
    Store(20, LENG)
    Store(0x1, CMDD) // EC_TAS_GET_GCP
    Store(ToUUID("23ea63ed-b593-46ea-b027-8924df88e92f"), UUID) // RTC
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (GCDD)
    }
  }
  Return(Zero)
}
```

## EC_TAS_GET_GRT

This object is required if the capabilities bit 2 is set to 1. The OSPM
can use this object to get time. The return value is a buffer containing
the time information as described below.

[9. ACPI-Defined Devices and Device-Specific Objects — ACPI
Specification 6.5
documentation](https://uefi.org/specs/ACPI/6.5/09_ACPI_Defined_Devices_and_Device_Specific_Objects.html#grt-get-real-time)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example
```
Method (_GRT) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(32){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,144,128,GRTD) // Out – 128-bit output structure above

    Store(20, LENG)
    Store(0x2, CMDD) // EC_TAS_GET_GRT
    Store(ToUUID("23ea63ed-b593-46ea-b027-8924df88e92f"), UUID) // RTC
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (GRTD)
    }
  }
  Return(Zero)
}
```

## EC_TAS_SET_SRT

This object is required if the capabilities bit 2 is set to 1. The OSPM
can use this object to set the time.

[9. ACPI-Defined Devices and Device-Specific Objects — ACPI
Specification 6.5
documentation](https://uefi.org/specs/ACPI/6.5/09_ACPI_Defined_Devices_and_Device_Specific_Objects.html#srt-set-real-time)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example
```
Method (_SRT) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(30){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,152,128,GRTD) // In – 128-bit output structure above

    Store(20, LENG)
    Store(0x3, CMDD) // EC_TAS_SET_SRT
    Store(ToUUID("23ea63ed-b593-46ea-b027-8924df88e92f"), UUID) // RTC
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (One)
    }
  }
  Return(Zero)}
}
```

## EC_TAS_GET_GWS

This object is required if the capabilities bit 0 is set to 1. It
enables the OSPM to read the status of wake alarms

[9. ACPI-Defined Devices and Device-Specific Objects — ACPI
Specification 6.5
documentation](https://uefi.org/specs/ACPI/6.5/09_ACPI_Defined_Devices_and_Device_Specific_Objects.html#gws-get-wake-alarm-status)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example
```
Method (_GWS) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(30){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDwordField(BUFF,19, GWS1) // In – Dword for timer type AC/DC
    CreateField(BUFF,144,32,GWSD) // Out – Dword timer state

    Store(20, LENG)
    Store(0x4, CMDD) // EC_TAS_GET_GWS
    Store(ToUUID("23ea63ed-b593-46ea-b027-8924df88e92f"), UUID) // RTC
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (GWSD)
    } 
  } 
  Return(Zero)
}
```
##  EC_TAS_SET_CWS

This object is required if the capabilities bit 0 is set to 1. It
enables the OSPM to clear the status of wake alarms

[9. ACPI-Defined Devices and Device-Specific Objects — ACPI
Specification 6.5
documentation](https://uefi.org/specs/ACPI/6.5/09_ACPI_Defined_Devices_and_Device_Specific_Objects.html#cws-clear-wake-alarm-status)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example

```
Method (_CWS) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(30){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDwordField(BUFF,19, GWS1) // In – Dword for timer type AC/DC
    CreateField(BUFF,144,32,CWSD) // Out – Dword timer state
 
    Store(20, LENG)
    Store(0x5, CMDD) // EC_TAS_SET_CWS
    Store(Arg0,GWS1)
    Store(ToUUID("23ea63ed-b593-46ea-b027-8924df88e92f"), UUID) // RTC
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (CWSD)
    }
  } 
  Return(Zero)
}
```

## EC_TAS_SET_STV

This object is required if the capabilities bit 0 is set to 1. It sets
the timer to the specified value. 

[9. ACPI-Defined Devices and Device-Specific Objects — ACPI
Specification 6.5
documentation](https://uefi.org/specs/ACPI/6.5/09_ACPI_Defined_Devices_and_Device_Specific_Objects.html#stv-set-timer-value)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example
```
Method (_STV) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(30){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDwordField(BUFF,19, GWS1) // In – Dword for timer type AC/DC
    CreateDwordField(BUFF,23, GWS2) // In – Dword Timer Value
    CreateField(BUFF,144,32,STVD) // Out – Dword timer state

    Store(20, LENG)
    Store(0x6, CMDD) // EC_TAS_SET_STV
    Store(Arg0,GWS1)
    Store(Arg1,GWS2)
    Store(ToUUID("23ea63ed-b593-46ea-b027-8924df88e92f"), UUID) // RTC
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
  
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (STVD)
    }
  }
  Return(Zero)
}
```

## EC_TAS_GET_TIV

This object is required if the capabilities bit 0 is set to 1. It
returns the remaining time of the specified timer before that expires.

[9. ACPI-Defined Devices and Device-Specific Objects — ACPI
Specification 6.5
documentation](https://uefi.org/specs/ACPI/6.5/09_ACPI_Defined_Devices_and_Device_Specific_Objects.html#tiv-timer-values)

### Input Parameters

Input parameters as described in ACPI specification.

### Output Parameters

Should return structure as defined by ACPI specification

### FFA ACPI Example

```
Method (_TIV) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(30){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDwordField(BUFF,19, GWS1) // In – Dword for timer type AC/DC
    CreateField(BUFF,144,32,TIVD) // Out – Dword timer state

    Store(20, LENG)
    Store(0x7, CMDD) // EC_TAS_GET_TIV
    Store(Arg0,GWS1)
    Store(ToUUID("23ea63ed-b593-46ea-b027-8924df88e92f"), UUID) // RTC
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (TIVD)
    }
  }
  Return(Zero)
}
```
