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
    Name(BUFF, Buffer(32){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateField(BUFF,144,32,FWSD) // Out – Raw data response (overlaps with CMDD)

    Store(ToUUID("330c1273-fde5-4757-9819-5b6539037502"), UUID) // Management
    Store(20, LENG)
    Store(0x1, CMDD) // EC_CAP_GET_FW_STATE
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
      Return (FWSD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
}
```

## Get Features Supported

Get a list of services/features supported by this EC. Several features
like HID devices are optional and may not be present. OEM services may
also be added to this list as additional features supported.

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
<td>DebugMask</td>
<td>16</td>
<td><p>0 – Supports reset reason</p>
<p>1 – Supports debug tracing</p></td>
</tr>
<tr class="even">
<td>BatteryMask</td>
<td>8</td>
<td><p>0 – Battery 0 present</p>
<p>1 – Battery 1 present</p>
<p>…</p></td>
</tr>
<tr class="odd">
<td>FanMask</td>
<td>8</td>
<td><p>0 – FAN 0 present</p>
<p>1 – FAN 1 present</p>
<p>…</p></td>
</tr>
<tr class="even">
<td>ThermalMask</td>
<td>8</td>
<td>0 – Skin TZ present</td>
</tr>
<tr class="odd">
<td>HIDMask</td>
<td>8</td>
<td><p>0 – HID0 present</p>
<p>1 – HID1 present</p>
<p>…</p></td>
</tr>
<tr class="even">
<td>KeyMask</td>
<td>16</td>
<td><p>0 – Power key present</p>
<p>1 – LID switch present</p>
<p>2 – VolUp Key Present</p>
<p>3 – VolDown Key Present</p>
<p>4 – Camera Key Present</p></td>
</tr>
<tr class="odd">
<td></td>
<td></td>
<td></td>
</tr>
</tbody>
</table>

### FFA ACPI Example
```
Method(TFET, 0x0, Serialized) {
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(24){})
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18,CMDD) // Command register
    CreateField(BUFF,144,48,FETD) // Output Data

    Store(20, LENG)
    Store(0x2, CMDD) // EC_CAP_GET_SVC_LIST
    Store(ToUUID("330c1273-fde5-4757-9819-5b6539037502"), UUID)
    Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) {
      Return (FETD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
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
    Name(BUFF, Buffer(32){})
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18,CMDD) // Command register
    CreateDwordField(BUFF,18,BIDD) // Output Data
    Store(20, LENG)
    Store(0x3, CMDD) // EC_CAP_GET_BID
    Store(ToUUID("330c1273-fde5-4757-9819-5b6539037502"), UUID)
    Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) {
      Return (BIDD)
    } else {
      Return(Zero)
    }
  } else {
    Return(Zero)
  }
}
```

## Firmware Update

This should initiate update of a particular firmware in the backup
partition to provide NIST SP 800-193 failsafe compliance. EC firmware
update is planned to be handled through CFU. Further details are
available in CFU specification.
