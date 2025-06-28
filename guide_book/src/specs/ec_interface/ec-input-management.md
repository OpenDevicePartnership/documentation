# EC Input Management

An EC may have several input devices including LID, Power key, touch and
keyboard. HID based devices requiring low latency input, are recommended
to be connected directly through a non-secure BUS interface such as I2C
or I3C for performance reasons.

## LID State

Monitor sensors that indicate lid state. If lid is opened, potentially
boot the system. If lid is closed, potentially shut down or hibernate
the system.

| **ACPI** | **Description**                               |
| -------- | --------------------------------------------- |
| _LID    | Get state of LID device for clamshell designs |

### ACPI Example for LID notificiation

Assuming that LID is managed by the EC during registration we register
for Input Management service for a Virtual ID = 1

```
 Name(_DSD, Package() {
      ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), //Device Prop UUID
      Package() {
        Package(2) {
          "arm-arml0002-ffa-ntf-bind",
          Package() {
              1, // Revision
              1, // Count of following packages
              Package () {
                     ToUUID("e3168a99-4a57-4a2b-8c5e-11bcfec73406"), // Input Management UUID
                     Package () {
                          0x02,     // Cookie for LID
                      }
              },
         }
      }
    }
  }) // _DSD()

  Method(_DSM, 0x4, NotSerialized)
  {
    // Arg0 - UUID
    // Arg1 - Revision
    // Arg2: Function Index
    //         0 - Query
    //         1 - Notify
    //         2 - binding failure
    //         3 - infra failure    
    // Arg3 - Data
  
    //
    // Device specific method used to query
    // configuration data. See ACPI 5.0 specification
    // for further details.
    //
    If(LEqual(Arg0, Buffer(0x10) {
        //
        // UUID: {7681541E-8827-4239-8D9D-36BE7FE12542}
        //
        0x1e, 0x54, 0x81, 0x76, 0x27, 0x88, 0x39, 0x42, 0x8d, 0x9d, 0x36, 0xbe, 0x7f, 0xe1, 0x25, 0x42
      }))
    {
      // Query Function
      If(LEqual(Arg2, Zero)) 
      {
        Return(Buffer(One) { 0x03 }) // Bitmask Query + Notify
      }
      
      // Notify Function
      If(LEqual(Arg2, One))
      {
        // Arg3 - Package {UUID, Cookie}
        Local0 = DeRefOf(Index(Arg3,1))
        Switch(Local0) {
          Case(2) {
            Notify(\_SB._LID, 0x80)
          }
        }
      }
    }
    Return(Buffer(One) { 0x00 })
  }
```

## System Wake Event

Ability to wake the system from various external events. This is for
more complicated events that aren’t a simple GPIO for LID/Power button
that require EC monitoring.

## HID descriptor Interface

Communication with EC must have packet sent/received in HID format so
the OS HIDClass driver can properly understand requests. At this time
HID packets will go over HIDI2C but in future these HID packets could be
included over a single interface.

| **HID IOCTL**                        | **Description**                                                        |
| ------------------------------------ | ---------------------------------------------------------------------- |
| IOCTL_HID_GET_DEVICE_DESCRIPTOR  | Retrieves the device's HID descriptor                                  |
| IOCTL_HID_GET_DEVICE_ATTRIBUTES  | Retrieves a device's attributes in a HID_DEVICE_ATTRIBUTES structure |
| IOCTL_HID_GET_REPORT_DESCRIPTOR  | Obtains the report descriptor for the HID device                       |
| IOCTL_HID_READ_REPORT             | Returns a report from the device into a class driver-supplied buffer   |
| IOCTL_HID_WRITE_REPORT            | Transmits a class driver-supplied report to the device                 |
| IOCTL_HID_GET_FEATURE             | Get capabilities of a feature from the device                          |
| IOCTL_HID_SET_FEATURE             | Set/Enable a specific feature on device                                |
| IOCTL_HID_GET_INPUT_REPORT       | Get input report from HID device if input device                       |
| IOCTL_HID_SET_OUTPUT_REPORT      | Send output HID report to device                                       |
| IOCTL_HID_GET_STRING              | Get a specific string from device                                      |
| IOCTL_HID_GET_INDEXED_STRING     | Get a string from device based on index                                |
| IOCTL_HID_SEND_IDLE_NOTIFICATION | Notification to idle device into idle/sleep state                      |
