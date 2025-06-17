# Sample System Implementation

##  ACPI Interface Definition

### FFA Device Definition

```rust
Device(\\_SB_.FFA0) {
  Name(_HID, "MSFT000C")
  OperationRegion(AFFH, FFixedHw, 4, 144)
  Field(AFFH, BufferAcc, NoLock, Preserve) { AccessAs(BufferAcc, 0x1), FFAC, 1152 }

  // Other components check this to make sure FFA is available
  Method(AVAL, 0, Serialized) {
    Return(One)
  }

  // Register notification events from FFA
  Method(_RNY, 0, Serialized) {
    Return( Package() {
      Package(0x2) { // Events for Management Service
        ToUUID("330c1273-fde5-4757-9819-5b6539037502"),
        Buffer() {0x1,0x0} // Register event 0x1
      },
      Package(0x2) { // Events for Thermal service
        ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"),
        Buffer() {0x1,0x0,0x2,0x0,0x3,0x0} // Register events 0x1, 0x2, 0x3
      },
      Package(0x2) { // Events for input device
        ToUUID("e3168a99-4a57-4a2b-8c5e-11bcfec73406"),
        Buffer() {0x1,0x0} // Register event 0x1 for LID
      }
    } )
  }

  Method(_NFY, 2, Serialized) {
    // Arg0 == UUID
    // Arg1 == Notify ID
    // Management Service Events

    If(LEqual(ToUUID("330c1273-fde5-4757-9819-5b6539037502"),Arg0)) {
      Switch(Arg1) {
        Case(1) { // Test Notification Event
          Notify(\\_SB.ECT0,0x20)
        }
      }
    }

    // Thermal service events
    If(LEqual(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"),Arg0)) {
      Switch(Arg1) {
        Case(1) { // Temp crossed low threshold
          Notify(\\_SB.SKIN,0x80)
        }
        Case(2) { // Temp crossed high threshold
          Notify(\\_SB.SKIN,0x81)
        }
        Case(3) { // Critical temperature event
          Notify(\\_SB.SKIN,0x82)
        }
      }
    }

    // Input Device Events
    If(LEqual(ToUUID("e3168a99-4a57-4a2b-8c5e-11bcfec73406"),Arg0)) {
      Switch(Arg1) {
        Case(1) { // LID event
          Notify(\\_SB._LID,0x80)
        }
      }
    }
  }
}
```

### Memory Mapped Interface via FFA for UCSI

Note for this implementation of memory mapped interface to work the
memory must be marked as reserved by UEFI and not used by the OS and
direct access also given to the corresponding service in secure world.

```rust
Device(USBC) {
  Name(_HID,EISAID(“USBC000”))
  Name(_CID,EISAID(“PNP0CA0”))
  Name(_UID,1)
  Name(_DDN, “USB Type-C”)
  Name(_ADR,0x0)
  OperationRegion(USBC, SystemMemory, UCSI_PHYS_MEM, 0x30)
  Field(USBC,AnyAcc,Lock,Preserve)
  {
    // USB C Mailbox Interface
    VERS,16, // PPM-\>OPM Version
    RES, 16, // Reservied
    CCI, 32, // PPM-\>OPM CCI Indicator
    CTRL,64, // OPM-\>PPM Control Messages
    MSGI,128, // OPM-\>PPM Message In
    MSGO,128, // PPM-\>OPM Message Out
  }

  Method(_DSM,4,Serialized,0,UnknownObj, {BuffObj, IntObj,IntObj,PkgObj})
  {

    // Compare passed in UUID to Supported UUID
    If(LEqual(Arg0,ToUUID(“6f8398c2-7ca4-11e4-ad36-631042b5008f”)))
    {
      // Use FFA to send Notification event down to copy data to EC
      If(LEqual(\\_SB.FFA0.AVAL,One)) {
        Name(BUFF, Buffer(144){}) // Create buffer for send/recv data
        CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
        CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
        CreateField(BUFF,16,128,UUID) // UUID of service
        CreateByteField(BUFF,18, CMDD) // In – First byte of command
        CreateField(BUFF,144,1024,FIFD) // Out – Msg data

        // Create Doorbell Event
        Store(20, LENG)
        Store(0x0, CMDD) // UCSI set doorbell
        Store(ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), UUID)
        Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      } // End AVAL
    } // End UUID
  } // End DSM
}
```

### Thermal ACPI Interface for FFA

This sample code shows one Microsoft Thermal zone for SKIN and then a
thermal device THRM for implementing customized IO.

```rust
// Sample Definition of FAN ACPI
Device(SKIN) {
  Name(_HID, "MSFT000A")

  Method(_TMP, 0x0, Serialized) {
    If(LEqual(\\_SB.FFA0.AVAL,One)) {
      Name(BUFF, Buffer(30){})
      CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
      CreateField(BUFF,16,128,UUID) // UUID of service
      CreateByteField(BUFF,18,CMDD) // Command register
      CreateByteField(BUFF,19,TZID) // Temp Sensor ID
      CreateDWordField(BUFF,26,RTMP) // Output Data

      Store(20, LENG)
      Store(0x1, CMDD) // EC_THM_GET_TMP
      Store(0x2, TZID) // Temp zone ID for SKIIN
      Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID)
      Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        Return (RTMP)
      }
    }
    Return (Ones)
  }

  // Arg0 Temp sensor ID
  // Arg1 Package with Low and High set points
  Method(THRS,0x2, Serialized) {
    If(LEqual(\\_SB.FFA0.AVAL,One)) {
      Name(BUFF, Buffer(32){})
      CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
      CreateField(BUFF,16,128,UUID) // UUID of service
      CreateByteField(BUFF,18,CMDD) // Command register
      CreateByteField(BUFF,19,TZID) // Temp Sensor ID
      CreateDwordField(BUFF,20,VTIM) // Timeout
      CreateDwordField(BUFF,24,VLO) // Low Threshold
      CreateDwordField(BUFF,28,VHI) // High Threshold
      CreateDWordField(BUFF,18,TSTS) // Output Data

      Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID)
      Store(32, LENG)
      Store(0x2, CMDD) // EC_THM_SET_THRS
      Store(Arg0, TZID)
      Store(DeRefOf(Index(Arg1,0)),VTIM)
      Store(DeRefOf(Index(Arg1,1)),VLO)
      Store(DeRefOf(Index(Arg1,2)),VHI)
      Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        Return (TSTS)
      }
    }
    Return (0x3) // Hardware failure
  }

  // Arg0 GUID 1f0849fc-a845-4fcf-865c-4101bf8e8d79
  // Arg1 Revision
  // Arg2 Function Index
  // Arg3 Function dependent
  Method(_DSM, 0x4, Serialized) {
    If(LEqual(ToUuid("1f0849fc-a845-4fcf-865c-4101bf8e8d79"),Arg0)) {
      Switch(Arg2) {
        Case (0) {
          Return(0x3) // Support Function 0 and Function 1
        }
        Case (1) {
          Return( THRS(0x2, Arg3) ) // Call to function to set threshold
        }
      }
    }
    Return(0x3)
  }
}

Device(THRM) {
  Name(_HID, "MSFT000B")

  // Arg0 Instance ID
  // Arg1 UUID of variable
  // Return (Status,Value)
  Method(GVAR,2,Serialized) {
    If(LEqual(\\_SB.FFA0.AVAL,One)) {
      Name(BUFF, Buffer(38){})
      CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
      CreateField(BUFF,16,128,UUID) // UUID of service
      CreateByteField(BUFF,18,CMDD) // Command register
      CreateByteField(BUFF,19,INST) // Instance ID
      CreateWordField(BUFF,20,VLEN) // 16-bit variable length
      CreateField(BUFF,176,128,VUID) // UUID of variable to read
      CreateField(BUFF,208,64,RVAL) // Output Data

      Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID)
      Store(38, LENG)
      Store(0x5, CMDD) // EC_THM_GET_VAR
      Store(Arg0,INST) // Save instance ID
      Store(4,VLEN) // Variable is always DWORD here
      Store(Arg1, VUID)
      Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        Return (RVAL)
      }
    }
    Return (0x3)
  }

  // Arg0 Instance ID
  // Arg1 UUID of variable
  // Return (Status,Value)
  Method(SVAR,3,Serialized) {
    If(LEqual(\\_SB.FFA0.AVAL,One)) {
      Name(BUFF, Buffer(42){})
      CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
      CreateField(BUFF,16,128,UUID) // UUID of service
      CreateByteField(BUFF,18,CMDD) // Command register
      CreateByteField(BUFF,19,INST) // Instance ID
      CreateWordField(BUFF,20,VLEN) // 16-bit variable length
      CreateField(BUFF,176,128,VUID) // UUID of variable to read
      CreateDwordField(BUFF,38,DVAL) // Data value
      CreateField(BUFF,208,32,RVAL) // Ouput Data

      Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID)
      Store(42, LENG)
      Store(0x6, CMDD) // EC_THM_SET_VAR
      Store(Arg0,INST) // Save instance ID
      Store(4,VLEN) // Variable is always DWORD here
      Store(Arg1, VUID)
      Store(Arg2,DVAL)
      Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
      Return (RVAL)
      }
    }
    Return (0x3)
  }

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
      Return(0x1)
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
    }
    Return (0x1)
  }
}
```

##  Call Flows for secure and non-secure Implementation

Depending on system requirements the ACPI calls may go directly to the
EC or through secure world then through to EC.

When using non-secure interface the ACPI functions must define protocol
level which is the Embedded controller for eSPI. For I2C/I3C or SPI
interfaces the corresponding ACPI device must define the bus dependency
and build the packet directly that is sent to the EC.

For secure communication all data is sent to the secure world via FF-A
commands described in this document and the actual bus protocol and data
sent to the EC is defined in the secure world in Hafnium. All support
for FF-A is inboxed in the OS by default so EC communication will always
work in any environment. However, FF-A is not supported in x86/x64
platforms so direct EC communication must be used on these platforms.

### Non-Secure eSPI Access

This call flow assumes using Embedded controller definition with
independent ACPI functions for MPTF support

#### Non-Secure eSPI READ

```rust
Device(EC0) {
  Name(_HID, EISAID("PNP0C09")) // ID for this EC

  // current resource description for this EC
  Name(_CRS, ResourceTemplate() {
    Memory32Fixed (ReadWrite, 0x100000, 0x10) // Used for simulated port access
    Memory32Fixed (ReadWrite, 0x100010, 0x10)
    // Interrupt defined for eSPI event signalling
    GpioInt(Edge, ActiveHigh, ExclusiveAndWake,PullUp 0,"\\_SB.GPI2"){43} 
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
    BST1, 32, // Battery State
    BST2, 32, // Battery Present Rate
    BST3, 32, // Battery Remaining capacity
    BST4, 32, // Battery Present Voltage
  }

  Method (_BST) {
    Name (BSTD, Package (0x4)
    {
      \\_SB.PCI0.ISA0.EC0.BST1, // Battery State
      \\_SB.PCI0.ISA0.EC0.BST2, // Battery Present Rate
      \\_SB.PCI0.ISA0.EC0.BST3, // Battery Remaining Capacity
      \\_SB.PCI0.ISA0.EC0.BST4, // Battery Present Voltage
    })
    Return(BSTD)
  }
}
```

![A diagram of a communication system AI-generated content may be
incorrect.](media/image12.png)

#### Non-Secure eSPI Notifications

All interrupts are handled by the ACPI driver. When EC needs to send a
notification event the GPIO is asserted and traps into IRQ. ACPI driver
reads the EC_SC status register to determine if an SCI is pending. DPC
callback calls and reads the EC_DATA port to determine the _Qxx event
that is pending. Based on the event that is determined by ACPI the
corresponding _Qxx event function is called.

```rust
Method (_Q07) {
  // Take action for event 7
  Notify(\\_SB._LID, 0x80)
}
```

![A diagram of a non-secure notification AI-generated content may be
incorrect.](media/image13.png)

### Secure eSPI Access

The following flow assumes ARM platform using FF-A for secure calls.
Note if you want to use the same EC firmware on both platforms with
secure and non-secure access the EC_BAT_GET_BST in this case should
be convert to a peripheral access with the same IO port and offset as
non-secure definition.

#### Secure eSPI READ
```rust
Method (_BST) {
  // Check to make sure FFA is available and not unloaded
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
    Name(BUFF, Buffer(32){}) // Create buffer for send/recv data
    CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
    CreateField(BUFF,16,128,UUID) // UUID of service
    CreateByteField(BUFF,18, CMDD) // In – First byte of command
    CreateDwordField(BUFF,19, BMA1) // In – Averaging Interval
    CreateField(BUFF,144,128,BSTD) // Out – 4 DWord BST data

    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID) // Battery
    Store(42, LENG)
    Store(0x6, CMDD) // EC_BAT_GET_BST
    Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
    Return (BMAD)
    } 
  } 
  Return(Zero)
}
```

![A diagram of a communication system AI-generated content may be
incorrect.](media/image14.png)

#### Secure eSPI Notification

When EC communication is done through Secure world we assert FIQ which
is handled as eSPI interrupt. eSPI driver reads EC_SC and EC_DATA to
retrieve the notification event details. On Non-secure implementation
ACPI converts this to Qxx callback. On secure platform this is converted
to a virtual ID and sent back to the OS via _NFY callback and a virtual
ID.

```rust
Method(_NFY, 2, Serialized) {
  // Arg0 == UUID
  // Arg1 == Notify ID
  If(LEqual(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"),Arg0)) {
    If(LEqual(0x2,Arg1)) {
      Store(Arg1, \\_SB.ECT0.NEVT)
      Notify(\\_SB._LID, 0x80)
    }
  }
}
```

![A diagram of a event AI-generated content may be
incorrect.](media/image15.png)
