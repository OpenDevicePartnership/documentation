# EC Debug Service

The debug service is used for telemetry, debug logs, system reset
information etc.

## Recovery Mode

Put EC into recovery mode for development flashing and debugging.

## Dump Debug State

EC should be able to support typical engineering requests, such as
getting detailed subsystem information, setting/getting GPIOs, etc, for
design verification and benchtop testing.

## Telemetry

Ability to communicate with the HLOS event logging system, and record EC
critical events for later analysis.

## System Boot State

In many designs, OEMs will desire indication that the system is
responding to a power on request. This could be a logo display on the
screen or a bezel LED. EC should be able to control these devices during
the boot sequence.

During first boot sequence EC may also be initialized and setup its
services. Needs to know when OS is up to send notification for events
that are only used by OS.

## Memory Mapped Transactions

There are two cases where you may want to use the memory mapped
transactions. The first is if you have a large buffer you need to
transfer data between EC and HLOS like a debug buffer. The second use
case is if you want to emulate an eSPI memory mapped interface for
compatibility with legacy devices.

For this mode to work you will need memory carved out which is dedicated
and shared between HLOS and secure world. In your UEFI memory map this
memory should be marked as EfiMemoryReservedType so that the OS will not
use or allocate the memory. In your SP manifest file you will also need
to add access to this physical memory range. It needs to be aligned on a
4K boundary and a multiple of 4K. This memory region is carved out and
must never be used for any other purpose. Since the memory is shared
with HLOS there is also no security surrounding accesses to the memory.

### Example Memory Mapped Interface

```
// Map 4K memory region
OperationRegion(ABCD, SystemMemory, 0xFFFF0000, 0x1000)

// Map fields in region if you want to access or set via ACPI
Field(ABCD,AnyAcc,Lock,Preserve) {
  VER,16, // Version
  RES, 16, // Reserved
  VAR1,32, // 32-bit variable1
  VAR2,64, // 64-bit variable1
  VAR3,128, // 128-bit variable1
}

// DSM Method to send sync event
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

      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        Return (Zero)
      } else {
        Return(One)
      }
    } // End AVAL
  } // End UUID
} // End DSM

```

Any updates from the EC come back through a notification event
registered in the FFA for this particular service.

