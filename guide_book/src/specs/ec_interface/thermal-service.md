# Thermal Zone Service

Battery temperature and other temperatures are read through a modified
thermal interface called Microsoft Temperature Sensor that implements
the _TMP and _DSM functionality. There is also still a generic thermal
zone interface which has a few more entries for system outside of MPTF.

| **Command**              | **Description**                                                      |
| ------------------------ | -------------------------------------------------------------------- |
| EC_THM_GET_TMP = 0x1  | Returns the thermal zone’s current temperature in tenths of degrees. |
| EC_THM_SET_THRS = 0x2 | Sets the thresholds for high, low and timeout.                       |
| EC_THM_GET_THRS = 0x3 | Get thresholds for low and high points                               |
| EC_THM_SET_SCP = 0x4  | Set cooling Policy for thermal zone                                  |
| EC_THM_GET_VAR = 0x5  | Read DWORD variable related to thermal                               |
| EC_THM_SET_VAR = 0x6  | Write DWORD variable related to thermal                              |

## EC_THM_GET_TMP

The Microsoft Thermal Sensor is a simplified [ACPI Thermal Zone
object](https://uefi.org/specs/ACPI/6.5/11_Thermal_Management.html?highlight=_tmp),
it only keeps the temperature input part of the thermal zone. It is used
as the interface to send temperatures from the hardware to the OS. Like
the thermal zone, Thermal Sensor also supports getting temperatures
through _TMP method.

### Input Parameters

Arg0 – Byte Thermal Zone Identifier

### Output Parameters

An Integer containing the current temperature of the thermal zone (in
tenths of degrees Kelvin)

The return value is the current temperature of the thermal zone in
tenths of degrees Kelvin. For example, 300.0K is represented by the
integer 3000.

### FFA ACPI Example

```
Method (_TMP) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\_SB.FFA0.AVAL,One)) {
    CreateDwordField(BUFF, 0, STAT) // Out – Status
    CreateField(BUFF, 128, 128, UUID) // UUID of service
    CreateByteField(BUFF, 32, CMDD) // Command register
    CreateByteField(BUFF, 33, TMP1) // In – Thermal Zone Identifier
    CreateDwordField(BUFF, 34, TMPD) // Out – temperature for TZ

    Store(0x1, CMDD) // EC_THM_GET_TMP
    Store(1,TMP1)
    Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID) // Thermal
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (TMPD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
}
```

## EC_THM_SET_THRS

Update thresholds for thermal zone

The platform should inform the OSPM to read _TMP method through
Notify(device, 0x80) when **<span class="underline">any</span>** of
below conditions is met: 

  - The **Timeout** has been met. 

<!-- end list -->

  - The current temperature crosses the zone specified by
    **LowTemperature** or **HighTemperature**. 

### Input Parameters

Arg0 – Byte Thermal Zone Identifier

Arg1 – Timeout // Integer (DWORD) in mS

Arg2 – LowTemperature // Integer (DWORD) in tenth deg Kelvin

Arg3 - HighTemperature // Integer (DWORD) in tenth deg Kelvin

### Output Parameters

Integer with status

  - 0x00000000: Succeed 

  - 0x00000001: Failure, invalid parameter 

  - 0x00000002: Failure, unsupported revision 

  - 0x00000003: Failure, hardware error 

  - Others: Reserved 

### FFA ACPI Example

```
Method(_DSM,4,Serialized,0,UnknownObj, {BuffObj, IntObj,IntObj,PkgObj}) {
  // Compare passed in UUID to Supported UUID
  If(LEqual(Arg0,ToUUID(“1f0849fc-a845-4fcf-865c-4101bf8e8d79 ”)))
  {

  // Implement function 1 which is update threshold
  If(LEqual(Arg2,One)) {
    // Check to make sure FFA is available and not unloaded
    If(LEqual(\_SB.FFA0.AVAL,One)) {
      CreateDwordField(BUFF, 0, STAT) // Out – Status
      CreateField(BUFF, 128, 128, UUID) // UUID of service
      CreateByteField(BUFF, 32, CMDD) // Command register
      CreateByteField(BUFF, 33, TID1) // In – Thermal Zone Identifier
      CreateDwordField(BUFF, 34, THS1) // In – Timeout in ms
      CreateDwordField(BUFF, 38, THS2) // In – Low threshold tenth Kelvin
      CreateDwordField(BUFF, 42, THS3) // In – High threshold tenth Kelvin
      CreateDwordField(BUFF, 46, THSD) // Out – Status from EC

      Store(0x2, CMDD) // EC_THM_SET_THRS
      Store(1,TID1)
      Store(Arg0,THS1)
      Store(Arg1,THS2)
      Store(Arg2,THS3)
      Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID) // Thermal
      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        Return (THSD)
      }
    }
    Return(Zero)
  }
}
```

## EC_THM_GET_THRS

Read back thresholds that have been set or default thresholds that exist
on the EC.

### Input Parameters

Arg0 - Thermal ID – Identifier to determine which TZ to read the
thresholds for

### Output Parameters

Arg0 – Status // 0 on success or neagtive error code

Arg1 – Timeout // Integer (DWORD) in mS

Arg2 – LowTemperature // Integer (DWORD) in tenth deg Kelvin

Arg3 - HighTemperature // Integer (DWORD) in tenth deg Kelvin

### FFA ACPI Example
```
Method(_DSM,4,Serialized,0,UnknownObj, {BuffObj, IntObj,IntObj,PkgObj}) {
  // Compare passed in UUID to Supported UUID
  If(LEqual(Arg0,ToUUID(“1f0849fc-a845-4fcf-865c-4101bf8e8d79 ”)))
  {
    // Implement function 2 which is update threshold
    If(LEqual(Arg2,Two)) {
      // Check to make sure FFA is available and not unloaded
      If(LEqual(\_SB.FFA0.AVAL,One)) {
        CreateDwordField(BUFF, 0, STAT) // Out – Status
        CreateField(BUFF, 128, 128, UUID) // UUID of service
        CreateByteField(BUFF, 32, CMDD) // Command register
        CreateByteField(BUFF, 33, TID1) // In – Thermal Zone Identifier
        CreateDwordField(BUFF, 34, THS1) // Out – Timeout in ms
        CreateDwordField(BUFF, 38, THS2) // Out – Low threshold tenth Kelvin
        CreateDwordField(BUFF, 42, THS3) // Out – High threshold tenth Kelvin

        Store(0x3, CMDD) // EC_THM_GET_THRS
        Store(1,TID1)
        Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID) // Thermal
        Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

        If(LEqual(STAT,0x0) ) // Check FF-A successful?
        {
          Return (Package () {THS1, THS2, THS3})
        } 
    }
    Return(Zero)
  }
}
```

## EC_THM_SET_SCP

This optional object is a control method that OSPM invokes to set the
platform’s cooling mode policy setting. 

### Input Parameters

Arg0 - Identifier to determine which TZ to read the thresholds for

Arg1 - Mode An Integer containing the cooling mode policy code

Arg2 - AcousticLimit An Integer containing the acoustic limit

Arg3 - PowerLimit An Integer containing the power limit

### Output Parameters

Arg0 – Status from EC

  - 0x00000000: Succeed 

  - 0x00000001: Failure, invalid parameter 

  - 0x00000002: Failure, unsupported revision 

  - 0x00000003: Failure, hardware error 

  - Others: Reserved 

### FFA ACPI Example
```
Method (_SCP) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\_SB.FFA0.AVAL,One)) {
    CreateDwordField(BUFF, 0, STAT) // Out – Status
    CreateField(BUFF, 128, 128, UUID) // UUID of service
    CreateByteField(BUFF, 32, CMDD) // Command register
    CreateByteField(BUFF, 33, TID1) // In – Thermal Zone Identifier
    CreateDwordField(BUFF, 34, SCP1) // In – Timeout in ms
    CreateDwordField(BUFF, 38, SCP2) // In – Low threshold tenth Kelvin
    CreateDwordField(BUFF, 42, SCP3) // In – High threshold tenth Kelvin
    CreateDwordField(BUFF, 46, SCPD) // Out – Status from EC

    Store(0x4, CMDD) // EC_THM_SET_SCP
    Store(1,TID1)
    Store(Arg0,SCP1)
    Store(Arg1,SCP2)
    Store(Arg2,SCP3)
    Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID) // Thermal
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (SCPD)
    }
  }
  Return(Zero)
}
```
## EC_THM_GET_VAR

This API is to read a variable from the EC related to thermal. Variables
are defined as GUID’s and include length of variable to read. In the
case of default MPTF interface it is expecting a 32-bit variable.

### Input Parameters

Arg0 – 128-bit UUID the defines the variable

Arg1 – 16-bit Length field specifies the length of variable in bytes

### Output Parameters

Arg0 – 32-bit status field

  - 0x00000000: Succeed 

  - 0x00000001: Failure, invalid parameter 

  - 0x00000002: Failure, unsupported revision 

  - 0x00000003: Failure, hardware error 

  - Others: Reserved 

Var – Variable length data must match requested length otherwise should
return error code

### FFA ACPI Example

```
Method(GVAR,2,Serialized) {
  If(LEqual(\_SB.FFA0.AVAL,One)) {
    CreateDwordField(BUFF, 0, 64, STAT) // Out – Status
    CreateField(BUFF, 128, 128, UUID) // UUID of service
    CreateByteField(BUFF, 32, CMDD) // Command register
    CreateByteField(BUFF, 33, INST) // In – Instance ID
    CreateWordField(BUFF, 34, VLEN) // In – Variable Length in bytes
    CreateField(BUFF, 288, 128, VUID) // In – Variable UUID
    CreateQWordField(BUFF, 52, RVAL) // Out – Variable value

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
```

## EC_THM_SET_VAR

This API is to write a variable to the EC related to thermal. Variables
are defined as GUID’s and include length of variable to write. In the
case of default MPTF interface it is expecting a 32-bit variable.

### Input Parameters

Arg0 – 128-bit UUID the defines the variable

Arg1 – 16-bit Length field specifies the length of variable in bytes

Var - Variable length field of variable data

### Output Parameters

Arg0 – 32-bit status field

  - 0x00000000: Succeed 

  - 0x00000001: Failure, invalid parameter 

  - 0x00000002: Failure, unsupported revision 

  - 0x00000003: Failure, hardware error 

  - Others: Reserved 

### FFA ACPI Example
```
Method(SVAR,3,Serialized) {
  If(LEqual(\_SB.FFA0.AVAL,One)) {
    CreateQwordField(BUFF, 0, STAT) // Out – Status
    CreateField(BUFF, 128, 128, UUID) // UUID of service
    CreateByteField(BUFF, 32, CMDD) // Command register
    CreateByteField(BUFF, 33, INST) // In – Instance ID
    CreateWordField(BUFF, 34, VLEN) // In – Variable Length in bytes
    CreateField(BUFF, 288, 128, VUID) // In – Variable UUID
    CreateQwordField(BUFF, 52, DVAL) // In – Variable UUID
    CreateQwordField(BUFF, 60, RVAL) // Out – status

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

# Fan Service

The new MBTF framework depends on reading and writing variables on the
EC to allow the EC to make the best decisions on cooling. The
recommendations from the OS are aggregated on the EC side and decisions
are made on setting FAN speed based on these.

All the control of fan and thermal parameters is done through variable
interface using EC_THM_GET_VAR and EC_THM_SET_VAR.

## Fan and Thermal variables

It is optional to implement Dba and Sones.

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

## ACPI example of Input/Output _DSM

```
// Arg0 GUID
// 07ff6382-e29a-47c9-ac87-e79dad71dd82 - Input
// d9b9b7f3-2a3e-4064-8841-cb13d317669e - Output
// Arg1 Revision
// Arg2 Function Index
// Arg3 Function dependent

Method(_DSM, 0x4, Serialized) {
  // Input Variable
  If(LEqual(ToUuid("07ff6382-e29a-47c9-ac87-e79dad71dd82"),Arg0)) {
    Switch(Arg2) {
      Case(0) {
        // We support function 0-3
        Return(0xf)
      }
      Case(1) {
        Return(GVAR(1,ToUuid("ba17b567-c368-48d5-bc6f-a312a41583c1"))) // OnTemp
      }
      Case(2) {
        Return(GVAR(1,ToUuid("3a62688c-d95b-4d2d-bacc-90d7a5816bcd"))) // RampTemp
      }
      Case(3) {
        Return(GVAR(1,ToUuid("dcb758b1-f0fd-4ec7-b2c0-ef1e2a547b76"))) // MaxTemp
      }
    }
    Return(Ones)
  }

  // Output Variable
  If(LEqual(ToUuid("d9b9b7f3-2a3e-4064-8841-cb13d317669e"),Arg0)) {
    Switch(Arg2) {
      Case(0) {
        // We support function 0-3
        Return(0xf)
      }
      Case(1) {
        Return(SVAR(1,ToUuid("ba17b567-c368-48d5-bc6f-a312a41583c1"),Arg3)) // OnTemp
      }

      Case(2) {
        Return(SVAR(1,ToUuid("3a62688c-d95b-4d2d-bacc-90d7a5816bcd"),Arg3)) // RampTemp
      }

      Case(3) {
        Return(SVAR(1,ToUuid("dcb758b1-f0fd-4ec7-b2c0-ef1e2a547b76"),Arg3)) // MaxTemp
      }
    }
    Return(Ones)
  }
  Return (Ones)
}
```
