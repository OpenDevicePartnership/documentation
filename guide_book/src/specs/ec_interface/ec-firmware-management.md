# EC Firmware Management

This service is to provide details about the security state, supported
features, debug, firmware version and firmware update functionality.

NIST SP 800-193 compliance requires failsafe update of primary and
backup EC FW images. EC should run from primary partition while writing
backup partitions and then change flag to indicate backup becomes
primary and primary becomes backup.

| Capability Command            | Description                                                 |
| ----------------------------- | ----------------------------------------------------------- |
| EC_CAP_GET_FW_STATE = 0x1 | Return details of FW in EC, DICE, Secure Boot, Version, etc |
| EC_CAP_GET_SVC_LIST = 0x2 | Get list of services/features that this EC supports         |
| EC_CAP_GET_BID = 0x3       | Read Board ID that is used customized behavior              |
| EC_CAP_TEST_NFY = 0x4      | Create test notification event                              |

## Get Firmware State

Returns start of the overall EC if DICE and secure boot was enabled,
currently running firmware version, EC status like boot failures.

### Secure Boot and DICE

DICE is a specification from the Trusted Computing Group that allows the
MCU to verify the signature of the code that it is executing, thereby
establishing trust in the code. To do this, it has a primary bootloader
program that reads the firmware on flash and using a key that is only
accessible by the ROM bootloader, can verify the authenticity of the
firmware. 

[<span class="underline">Trusted Platform Architecture - Device Identity
Composition Engine
(trustedcomputinggroup.org)</span>](https://trustedcomputinggroup.org/wp-content/uploads/Hardware-Requirements-for-Device-Identifier-Composition-Engine-r78_For-Publication.pdf) 

### Input Parameters

None

### Output Parameters

<table>
<thead>
<tr class="header">
<th>Field</th>
<th>Bits</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>FWVersion</td>
<td>16</td>
<td>Version of FW running on EC</td>
</tr>
<tr class="even">
<td>SecureState</td>
<td>8</td>
<td><p>Bit mask representing the secure state of the device</p>
<p>0 – DICE is enabled</p>
<p>1 – Firmware is signed</p></td>
</tr>
<tr class="odd">
<td>BootStatus</td>
<td>8</td>
<td><p>Boot status and error codes</p>
<p>0 = SUCCESS</p></td>
</tr>
</tbody>
</table>

### FFA ACPI Example

```
Method (TFWS) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    CreateQwordField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32, CMDD) // In – First byte of command
    CreateDwordField(BUFF,32,FWSD) // Out – Raw data response (overlaps with CMDD)

    Store(ToUUID("330c1273-fde5-4757-9819-5b6539037502"), UUID) // Management
    Store(0x1, CMDD) // EC_CAP_GET_FW_STATE
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (FWSD)
    } 
  }
  Return(Zero)
}
```

## Get Features Supported

Get a list of services/features supported by this EC. Several features
like HID devices are optional and may not be present. OEM services may
also be added to this list as additional features supported.

### Input Parameters

None

### Output Parameters

| Field         | Bits  | Description
|---------------|-------|-------------------------
| DebugMask     | 16    | 0 - Supports reset reason<br>1 - Supports debug tracing
| BatteryMask   | 8     | 0 - Battery 0 present<br>1 - Battery 1 present<br>...
| FanMask       | 8     | 0 - Fan 0 present<br>1 - Fan 1 present<br>...
| ThermalMask   | 8     | 0 - Skin TZ present
| HIDMask       | 8     | 0 - HID0 present<br>1 - HID1 present<br>...
| KeyMask       | 16    | 0 - Power key present<br>1 - LID switch present<br>2 - VolUp key present<br>3 - VolDown key present<br>4 - Camera key present

### FFA ACPI Example
```
Method(TFET, 0x0, Serialized) {
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    CreateQwordField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32, CMDD) // In – First byte of command
    CreateWordField(BUFF,32,FET0) // DebugMask
    CreateByteField(BUFF,34,FET1) // BatteryMask
    CreateByteField(BUFF,35,FET2) // FanMask
    CreateByteField(BUFF,36,FET3) // ThermalMask
    CreateByteField(BUFF,37,FET4) // HIDMask
    CreateWordField(BUFF,38,FET5) // KeyMask

    Store(0x2, CMDD) // EC_CAP_GET_SVC_LIST
    Store(ToUUID("330c1273-fde5-4757-9819-5b6539037502"), UUID)
    Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) {
      Return (package () {FET0,FET1,FET2,FET3,FET4,FET5})
    }
  }
  Return(package () {0,0,0,0,0,0,0})
}
```

## Get Board ID

EC is often used to read pins or details to determine the HW
configuration based on GPIO’s or ADC values. This ID allows SW to change
behavior depending on this HW version information.

### Input Parameters

None

### Output Parameters

| Field   | Bits | Description    |
| ------- | ---- | -------------- |
| BoardID | 64   | Vendor defined |

### FFA ACPI Example
```
Method(TBID, 0x0, Serialized) {
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    CreateQwordField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32, CMDD) // In – First byte of command
    CreateDwordField(BUFF,32,BIDD) // Output Data

    Store(0x3, CMDD) // EC_CAP_GET_BID
    Store(ToUUID("330c1273-fde5-4757-9819-5b6539037502"), UUID)
    Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) {
      Return (BIDD)
    } else {
  }
  Return(Zero)
}
```

## Firmware Update

This should initiate update of a particular firmware in the backup
partition to provide NIST SP 800-193 failsafe compliance. EC firmware
update is planned to be handled through CFU. Further details are
available in CFU specification.
