# ACPI Entries for MPTF

Windows will boot and run without the MPTF driver loading, however it will not provide any inbox default handling of thermal control.

For any MPTF functionality the Core Driver must be loaded with the following ACPI entry
```
// MPTFCore Driver
Device(MPC0) {
  Name(_HID, "MSFT000D")
  Name (_UID, 1)
}
```

There is no requirement to define further resources through the core driver those are all controlled by the IO driver entries.

## Microsoft Temperature Sensor Driver

This driver is loaded uner MSFT000A entry, it must always define a _TMP method and _DSM with support for function 0 and function1. If just these two functions are supported function 0 will return 0x3

```
  Method (_TMP) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      Name(BUFF, Buffer(24){}) // Create buffer for send/recv data
      CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
      CreateField(BUFF,16,128,UUID) // UUID of service
      CreateByteField(BUFF,18, CMDD) // In – First byte of command
      CreateByteField(BUFF,19, TMP1) // In – Thermal Zone Identifier
      CreateField(BUFF,144,32,TMPD) // Out – temperature for TZ

      Store(20, LENG)
      Store(0x1, CMDD) // EC_THM_GET_TMP
      Store(1,TMP1)
      Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID) // Thermal
      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        Return (TMPD)
      }
    }
    Return(Zero)
  }

  // Update Thresholds
  Method(STMP, 0x2, Serialized) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      Name(BUFF, Buffer(32){}) // Create buffer for send/recv data
      CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
      CreateField(BUFF,16,128,UUID) // UUID of service
      CreateByteField(BUFF,18, CMDD) // In – First byte of command
      CreateByteField(BUFF,19, TID1) // In – Thermal Zone Identifier
      CreateDwordField(BUFF,20,THS1) // In – Timeout in ms
      CreateDwordField(BUFF,24,THS2) // In – Low threshold tenth Kelvin
      CreateDwordField(BUFF,28,THS3) // In – High threshold tenth Kelvin
      CreateField(BUFF,144,32,THSD) // Out – Status from EC

      Store(0x30, LENG)
      Store(0x2, CMDD) // EC_THM_SET_THRS
      Store(1,TID1)
      Store(0,THS1) // Timout in ms 0 ignore
      Store(Arg0,THS2) // Low Threshold
      Store(Arg1,THS3) // High Threshold
      Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID) // Thermal
      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        Return (THSD)
      }
    }
    Return(Zero)
  }


  // Arg0 GUID
  //      1f0849fc-a845-4fcf-865c-4101bf8e8d79 - Temperature GUID
  // Arg1 Revision
  // Arg2 Function Index
  // Arg3 Function dependent
  Method(_DSM, 0x4, Serialized) {
    // Input Variable
    If(LEqual(ToUuid("1f0849fc-a845-4fcf-865c-4101bf8e8d79"),Arg0)) {
        Switch(Arg2) {
          Case(0) {
            // We support function 0,1
            Return (Buffer() {0x03, 0x00, 0x00, 0x00})
          }
          // Update Thresholds
          // Arg3 = Package () { LowTemp, HighTemp }
          Case(1) {
            Return(STMP(DeRefOf(Index(Arg3,0)),DeRefOf(Index(Arg3,1)))) // Set Temp low and high threshold
          }
        }
    }

    Return (Ones)
  }
```

## Microsoft Customized IO Signal Driver

This driver is loaded under MSFT0011 entry, and must always define Function 0 for both input and output devices. Function 0 is a bitmask of all the other variables that are supported on this platform. If you support functions 1,2,3 you would return 0b1111 (0xf) to indicate support for function 0-3.

```
  // Arg0 GUID
  //      07ff6382-e29a-47c9-ac87-e79dad71dd82 - Input
  //      d9b9b7f3-2a3e-4064-8841-cb13d317669e - Output
  // Arg1 Revision
  // Arg2 Function Index
  // Arg3 Function dependent
  Method(_DSM, 0x4, Serialized) {
    // Input Variable
    If(LEqual(ToUuid("07ff6382-e29a-47c9-ac87-e79dad71dd82"),Arg0)) {
        Switch(Arg2) {
          Case(0) {
            // We support function 0-3
            Return (Buffer() {0x0f, 0x00, 0x00, 0x00})
          }
          Case(1) {
            Return(GVAR(1,ToUuid("db261c77-934b-45e2-9742-256c62badb7a"))) // MinRPM
          }
          Case(2) {
            Return(GVAR(1,ToUuid("5cf839df-8be7-42b9-9ac5-3403ca2c8a6a"))) // MaxRPM
          }
          Case(3) {
            Return(GVAR(1,ToUuid("adf95492-0776-4ffc-84f3-b6c8b5269683"))) // CurrentRPM
          }
        }
        Return(Ones)
    }
    // Output Variable
    If(LEqual(ToUuid("d9b9b7f3-2a3e-4064-8841-cb13d317669e"),Arg0)) {
        Switch(Arg2) {
          Case(0) {
            // We support function 0-3
            Return (Buffer() {0x0f, 0x00, 0x00, 0x00})
          }
          Case(1) {
            Return(SVAR(1,ToUuid("db261c77-934b-45e2-9742-256c62badb7a"),Arg3)) // MinRPM
          }
          Case(2) {
            Return(SVAR(1,ToUuid("5cf839df-8be7-42b9-9ac5-3403ca2c8a6a"),Arg3)) // MaxRPM
          }
          Case(3) {
            Return(SVAR(1,ToUuid("adf95492-0776-4ffc-84f3-b6c8b5269683"),Arg3)) // CurrentRPM
          }
        }
        Return(Ones)
    }

    Return (Ones)
  }
```

In this case we've assigned the following meanings to supported functions
```
Function 1 --> MinRPM
Function 2 --> MaxRPM
Function 3 --> CurrentRPM
```
The meaning of what Function 1 does is mapped by the configuration Blob for your device, so Function 1 need not always be MinRPM. For communication with the EC we've assigned UUID's to each variable we support on the EC. This allows us to keep the same UUID for MinRPM on all platform implementations even though it may be a different function.

The following is the list of UUID's and variables we have defined for our reference implementation, but further mappings can be added by OEM's as well.

<table>
<thead>
<tr class="header">
<th><strong>Variable</strong></th>
<th><strong>GUID</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<td>OnTemp</td>
<td>ba17b567-c368-48d5-bc6f-a312a41583c1</td>
<td>Lowest temperature at which the fan is turned on.</td>
</tr>
<td>RampTemp</td>
<td>3a62688c-d95b-4d2d-bacc-90d7a5816bcd</td>
<td>Temperature at which the fan starts ramping from min speed.</td>
</tr>
<td>MaxTemp</td>
<td>dcb758b1-f0fd-4ec7-b2c0-ef1e2a547b76</td>
<td>Temperature at top of fan ramp where fan is at maximum speed.</td>
</tr>
<td>CrtTemp</td>
<td>218246e7-baf6-45f1-aa13-07e4845256b8</td>
<td>Critical temperature at which we need to shut down the system.</td>
</tr>
<td>ProcHotTemp</td>
<td>22dc52d2-fd0b-47ab-95b8-26552f9831a5</td>
<td>Temperature at which the EC will assert the PROCHOT notification.</td>
</tr>
<td>MinRpm</td>
<td>db261c77-934b-45e2-9742-256c62badb7a</td>
<td>Minimum RPM FAN speed</td>
</tr>
<td>MinDba (Optional)</td>
<td>0457a722-58f4-41ca-b053-c7088fcfb89d</td>
<td>Minimum Dba from FAN</td>
</tr>
<td><p>MinSones (Optional)</td>
<td>311668e2-09aa-416e-a7ce-7b978e7f88be</td>
<td>Minimum Sones from FAN</td>
</tr>
<td>MaxRpm</td>
<td>5cf839df-8be7-42b9-9ac5-3403ca2c8a6a</td>
<td>Maximum RPM for FAN</td>
</tr>
<td>MaxDba (Optional)</td>
<td>372ae76b-eb64-466d-ae6b-1228397cf374</td>
<td>Maximum DBA for FAN</td>
</tr>
<td>MaxSones (Optional)</td>
<td>6deb7eb1-839a-4482-8757-502ac31b20b7</td>
<td>Maximum Sones for FAN</td>
</tr>
<td>ProfileType</td>
<td>23b4a025-cdfd-4af9-a411-37a24c574615</td>
<td>Set profile for EC, gaming, quiet, lap, etc</td>
</tr>
<td>CurrentRpm</td>
<td>adf95492-0776-4ffc-84f3-b6c8b5269683</td>
<td>The current RPM of FAN</td>
</tr>
<td>CurrentDba (Optional)</td>
<td>4bb2ccd9-c7d7-4629-9fd6-1bc46300ee77</td>
<td>The current Dba from FAN</td>
</tr>
<td>CurrentSones (Optional)</td>
<td>7719d686-02af-48a5-8283-20ba6ca2e940</td>
<td>The current Sones from FAN</td>
</tr>
</tbody>
</table>

## ACPI communication to EC
MPTF refers to input and output channel values, however these need to be communicated to the EC. Above code refers to GVAR and SVAR to get a variable or set a variable. The following ACPI shows example of how to conver this to an FFA command which is sent to the secure EC service and then communicated to the EC. Further details of how this data is sent to the EC is covered in the EC Service section.

```
  // Arg0 Instance ID
  // Arg1 UUID of variable
  // Return (Status,Value)
  Method(GVAR,2,Serialized) {
    If(LEqual(\_SB.FFA0.AVAL,One)) {
        Name(BUFF, Buffer(52){})
        CreateField(BUFF, 0, 64, STAT) // Out – Status
        CreateField(BUFF, 64, 64, RCVD) // ReceiverId(only lower 16-bits are used) 
        CreateField(BUFF, 128, 128, UUID) // UUID of service
        CreateField(BUFF, 256, 8, CMDD) // Command register
        CreateField(BUFF, 264, 8, INST) // In – Instance ID
        CreateField(BUFF, 272, 16, VLEN) // In – Variable Length in bytes
        CreateField(BUFF, 288, 128, VUID) // In – Variable UUID
        CreateField(BUFF, 264, 64, RVAL) // Out – Variable value

        Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID)
        Store(0x5, CMDD) // EC_THM_GET_VAR
        Store(Arg0,INST) // Save instance ID
        Store(4,VLEN) // Variable is always DWORD here
        Store(Arg1, VUID)
        Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    
        If(LEqual(STAT,0x0) ) // Check FF-A successful?
        {
        Return (RVAL)
        }
      }
      Return (Ones)
    }

  // Arg0 Instance ID
  // Arg1 UUID of variable
  // Return (Status,Value)
  Method(SVAR,3,Serialized) {
    If(LEqual(\_SB_.FFA0.AVAL,One)) {
      Name(BUFF, Buffer(56){})
    
      CreateField(BUFF, 0, 64, STAT) // Out – Status
      CreateField(BUFF, 64, 64, RCVD) // ReceiverId(only lower 16-bits are used) 
      CreateField(BUFF, 128, 128, UUID) // UUID of service
      CreateField(BUFF, 256, 8, CMDD) // Command register
      CreateField(BUFF, 264, 8, INST) // In – Instance ID
      CreateField(BUFF, 272, 16, VLEN) // In – Variable Length in bytes
      CreateField(BUFF, 288, 128, VUID) // In – Variable UUID
      CreateField(BUFF, 416, 32, DVAL) // In – Variable Data
      CreateField(BUFF, 264, 64, RVAL) // Out – Variable value

      Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID)
      Store(0x6, CMDD) // EC_THM_SET_VAR
      Store(Arg0,INST) // Save instance ID
      Store(4,VLEN) // Variable is always DWORD here
      Store(Arg1, VUID)
      Store(Arg2,DVAL)
      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        Return (RVAL)
      }
    }
    Return (Ones)
  }

```