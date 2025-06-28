# EC Service ACPI

Sometimes the GVAR and SVAR from CIO may directly map to memory mapped OpRegion in an EC controller such as on Intel platforms. In the case where EC service is present in the secure world on ARM platforms we need to setup a bit more content.

All the communication between non-secure side (NTOS) and secure side (EC Secure Partition) is done through a standard called FF-A.

[FF-A Specification](https://developer.arm.com/Architectures/Firmware%20Framework%20for%20A-Profile)

## FFA ACPI Defintion

Make sure in your system in ACPI you have FFA device defined and corresponding _DSD and _DSM methods according to FFA documentation.

```
Device(\_SB_.FFA0) {
  Name(_HID, "MSFT000C")

  OperationRegion(AFFH, FFixedHw, 2, 144) 
  Field(AFFH, BufferAcc, NoLock, Preserve) { AccessAs(BufferAcc, 0x1), FFAC, 1152 }     
  ...
  Method(AVAL,0x0, Serialized)
  {
    Return(One)
  }
```

This should also implment the AVAL function to determine that FFA is loaded and can be used by other ACPI references. If you directly reference FFA0 without checking this if the FFA driver is not loaded can lead to deadlock and other OS issues.

## Making FFA Calls

As previously documented in the MPTF section, in the SVAR and GVAR we make calls into FFA. This section documents those parameters in more detail.

```
    If(LEqual(\_SB.FFA0.AVAL,One)) {        // First check to make sure FFA0 device is available
        Name(BUFF, Buffer(52){})            // Allocate a buffer large enough for all input and output data
        CreateField(BUFF, 0, 64, STAT)      // All FFA commands must have 64-bits status returned
        CreateField(BUFF, 64, 64, RCVD)     // ReceiverId left as zero is populated by the framework
        CreateField(BUFF, 128, 128, UUID)   // UUID of service we want to talk to in this case Thermal Service
        CreateField(BUFF, 256, 8, CMDD)     // Command to send to this service
        CreateField(BUFF, 264, 8, INST)     // Remaining entries are command specific input and output structure definition
        CreateField(BUFF, 272, 16, VLEN) 
        CreateField(BUFF, 288, 128, VUID) 
        CreateField(BUFF, 264, 64, RVAL)    // Output structure will overlap with input data

        Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID) // Populate the Thermal Service UUID
        Store(0x5, CMDD)                    // Write command EC_THM_GET_VAR into buffer
        Store(Arg0,INST)                    // Save instance ID into buffer
        Store(4,VLEN)                       // Variable is always DWORD here
        Store(Arg1, VUID)                   // Variable UUID 
        
        Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF) // Writes BUFF to FFA operation region this actually sends FFA request and gets response
    
        If(LEqual(STAT,0x0) )               // Check FF-A successful?
        {
            Return (RVAL)                   // Return data in the out buffer
        }
      }
      // Otherwise return an error
```

For MPTF we mostly just need Get/Set varaible commands and notifications.

## EC Notifications

The EC can also send notifications back to the OS if certain events occur. All the notifications come initially through the FFA0 device. When device is defined in ACPI you must list all the logical notification events you expect and the handler for notifications.

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
                     ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), // UUID for thermal
                     Package () {
                          0x01,     // EC_THM_HOT
                          0x02,     // EC_THM_LOW crossed low threshold
                          0x03,     // EC_THM_HIGH crossed high threshold
                      }
              }
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
        Store(Local0,\_SB.ECT0.NEVT )

        Switch(Local0) {
          Case(1) {
            // Handle HOT notification
          }
          Case(2) {
            // Handle Low temp notification
          }
          Case(3) {
            // Handle High temp notification
          }
        }
      }
    } Else {
      Return(Buffer(One) { 0x00 })
    }
  }
```