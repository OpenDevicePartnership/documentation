# Secure EC Services Overview

In this section we review a system design where the EC communication is
in the secure world running in a dedicated SP. In a system without
secure world or where communication to EC is not desired to be secure
all the ACPI functions can be mapped directly to data from the EC
operation region.

The following github projects provide sample implementations of this interface:

[ACPI EC samples, Kernel mode test driver, User mode test driver](https://github.com/opendevicepartnership/ec-test-app)<br>
[Sample Secure Partition Service for EC services in RUST](https://github.com/opendevicepartnership/haf-ec-service)<br>
[RUST crate for FFA implementation in secure partition](https://github.com/opendevicepartnership/ffa)<br>

The following GUID’s have been designed to represent each service
operating in the secure partition for EC.

<table>
<thead>
<tr class="header">
<th>EC Service Name</th>
<th>Service GUID</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<td>EC_SVC_MANAGEMENT</td>
<td>330c1273-fde5-4757-9819-5b6539037502</td>
<td>Used to query EC functionality, Board info, version, security state, FW update</td>
</tr>
<td>EC_SVC_POWER</td>
<td>7157addf-2fbe-4c63-ae95-efac16e3b01c</td>
<td>Handles general power related requests and OS Sx state transition state notification</td>
</tr>
<td>EC_SVC_BATTERY</td>
<td>25cb5207-ac36-427d-aaef-3aa78877d27e</td>
<td>Handles battery info, status, charging</td>
</tr>
<td>EC_SVC_THERMAL</td>
<td>31f56da7-593c-4d72-a4b3-8fc7171ac073</td>
<td>Handles thermal requests for skin and other thermal events</td>
</tr>
<td>EC_SVC_UCSI</td>
<td>65467f50-827f-4e4f-8770-dbf4c3f77f45</td>
<td>Handles PD notifications and calls to UCSI interface</td>
</tr>
<td>EC_SVC_INPUT</td>
<td>e3168a99-4a57-4a2b-8c5e-11bcfec73406</td>
<td>Handles wake events, power key, lid, input devices (HID separate instance)</td>
</tr>
<td>EC_SVC_TIME_ALARM</td>
<td>23ea63ed-b593-46ea-b027-8924df88e92f</td>
<td>Handles RTC and wake timers.</td>
</tr>
<td>EC_SVC_DEBUG</td>
<td>0bd66c7c-a288-48a6-afc8-e2200c03eb62</td>
<td>Used for telemetry, debug control, recovery modes, logs, etc</td>
</tr>
<td>EC_SVC_TEST</td>
<td>6c44c879-d0bc-41d3-bef6-60432182dfe6</td>
<td>Used to send commands for manufacturing/factory test</td>
</tr>
<td>EC_SVC_OEM1</td>
<td>9a8a1e88-a880-447c-830d-6d764e9172bb</td>
<td>Sample OEM custom service and example piping of events</td>
</tr>
</tbody>
</table>

## FFA Overview

This section covers the components involved in sending a command to EC
through the FFA flow in windows. This path is specific to ARM devices
and a common solution with x64 is still being worked out. Those will
continue through the non-secure OperationRegion in the near term.

![A diagram of a computer security system Description automatically
generated](media/image1.png)

ARM has a standard for calling into the secure world through SMC’s and
targeting a particular service running in secure world via a UUID. The
full specification and details can be found here: [Firmware Framework
for A-Profile](https://developer.arm.com/Architectures/Firmware%20Framework%20for%20A-Profile)

The windows kernel provides native ability for ACPI to directly send and
receive FFA commands. It also provides a driver ffadrv.sys to expose a
DDI that allows other drivers to directly send/receive FFA commands
without needing to go through ACPI.

Hyper-V forwards the SMC’s through to EL3 to Hafnium which then uses the
UUID to route the request to the correct SP and service. From the
corresponding EC service it then calls into the eSPI or underlying
transport layer to send and receive the request to the physical EC.

### FFA Device Definition

The FFA device is loaded from ACPI during boot and as such requires a
Device entry in ACPI

```rust
  Name(_HID, "MSFT000C")

  OperationRegion(AFFH, FFixedHw, 4, 144) 
  Field(AFFH, BufferAcc, NoLock, Preserve) { AccessAs(BufferAcc, 0x1), FFAC, 1152 }     
    

  Name(_DSD, Package() {
      ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), //Device Prop UUID
      Package() {
        Package(2) {
          "arm-arml0002-ffa-ntf-bind",
          Package() {
              1, // Revision
              2, // Count of following packages
              Package () {
                     ToUUID("330c1273-fde5-4757-9819-5b6539037502"), // Service1 UUID
                     Package () {
                          0x01,     //Cookie1 (UINT32)
                          0x07,     //Cookie2
                      }
              },
              Package () {
                     ToUUID("b510b3a3-59f6-4054-ba7a-ff2eb1eac765"), // Service2 UUID
                     Package () {
                          0x01,     //Cookie1
                          0x03,     //Cookie2
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
        Store(Index(Arg3,1), \_SB.ECT0.NEVT )
        Return(Zero) 
      }
    } Else {
      Return(Buffer(One) { 0x00 })
    }
  }

  Method(AVAL,0x0, Serialized)
  {
    Return(One)
  }
}
```

#### HID definition

The _HID “MSFT000C” is reserved for FFA devices. Defining this HID for
your device will cause the FFA interface for the OS to be loaded on this
device.

#### Operation Region Definition

The operation region is marked as FFixedHw type 4 which lets the ACPI
interpreter know that any read/write to this region requires special
handling. The length is 144 bytes because this region operates on
registers X0-X17 each of which are 8 bytes 18\*8 = 144 bytes. This is
mapped to FFAC is 1152 bits (144\*8) and this field is where we act
upon.

```rust
OperationRegion(AFFH, FFixedHw, 4, 144)
Field(AFFH, BufferAcc, NoLock, Preserve) { AccessAs(BufferAcc, 0x1),FFAC, 1152 }
```

When reading and writing from this operation region the FFA driver does
some underlying mapping for X0-X3

```
X0 = 0xc400008d // FFA_DIRECT_REQ2
X1 = (Receiver Endpoint ID) | (Sender Endpoint ID \<\< 16)
X2/X3 = UUID
```

The following is the format of the request and response packets that are
sent via ACPI

```rust
FFA_REQ_PACKET
{
  uint8 status; // Not used just populated so commands are symmetric
  uint8 length; // Number of bytes in rawdata
  uint128 UUID;
  uint8 reqdata[];
}

FFA_RSP_PACKET
{
  uint8 status; // Status from ACPI if FFA command was sent successfully
  uint8 length;
  uint128 UUID;
  uint64 ffa_status; // Status returned from the service of the FFA command
  uint8 rspdata[];
}

CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
CreateField(BUFF,16,128,UUID) // In/Out - UUID of service
CreateDwordField(BUFF,18,FFST)// Out - FFA command status
```

#### Register Notification

During FFA driver initialization it calls into secure world to get a
list of all available services for each secure partition. After this we
send a NOTIFICATION_REGISTRATION request to each SP that has a service
which registers for notification events

```rust
  Name(_DSD, Package() {
      ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), //Device Prop UUID
      Package() {
        Package(2) {
          "arm-arml0002-ffa-ntf-bind",
          Package() {
              1, // Revision
              1, // Count of following packages
              Package () {
                     ToUUID("330c1273-fde5-4757-9819-5b6539037502"), // Service1 UUID
                     Package () {
                          0x01,     //Cookie1 (UINT32)
                          0x07,     //Cookie2
                      }
              },
         }
      }
    }
  }) // _DSD()
```

![A diagram of a application Description automatically
generated](media/image2.png)

In the above example we indicate that the OS will handle 2 different
notification events for UUID 330c1273-fde5-4757-9819-5b6539037502 which
is our EC management UUID. FFA knows which secure partition this maps to
based on the list of services for each SP it has retrieved. Rather than
having to keep track of all the physical bits in the bitmask that are
used the FFA driver keeps track of this and allows each service to
create a list of virtual ID’s they need to handle. The FFA driver then
maps this to one of the available bits in the hardware bitmask and
passes this mapping down to the notification service running in a given
SP.

<h3>Input</h3>
<table>
<thead>
<tr class="header">
<th><strong>Parameter </strong></th>
<th><strong>Register </strong></th>
<th><strong>Value </strong></th>
</tr>
</thead>
<tbody>
<td>Function<strong> </strong></td>
<td>X4 </td>
<td>0x1 </td>
</tr>
<td>UUID Lo<strong> </strong></td>
<td>X5 </td>
<td>Bytes [0..7] for the service UUID. </td>
</tr>
<td>UUID Hi<strong> </strong></td>
<td>X6 </td>
<td>Bytes [8..16] for the service UUID. </td>
</tr>
<td>Mappings Count<strong> </strong></td>
<td>X7 </td>
<td>The number of notification mappings </td>
</tr>
<td>Notification Mapping1<strong> </strong></td>
<td>X8 </td>
<td><p>Bits [0..16] – Notification ID. --&gt; 0,1,2,3,... </p>
<p> </p>
<p>Bits [16..32] – Notification Bitmap bit number (0-383).  </p></td>
</tr>
<td>Notification Mapping2<strong> </strong></td>
<td>X9 </td>
<td><p>Bits [0..16] – Notification ID. --&gt; 0,1,2,3,... </p>
<p> </p>
<p>Bits [16..32] – Notification Bitmap bit number (0-383). </p>
<p> </p></td>
</tr>
<td>...<strong> </strong></td>
<td>... </td>
<td>... </td>
</tr>
</tbody>
</table>

 

<h3>Output</h3>

| Parameter  | Register  | Value                        |
| ---------- | --------- | -------------------------------- |
| Result     | X4        | 0 on success. Otherwise, Failure |

 

Note this NOTIFICATION_REGISTER request is sent to the
Notification Service UUID in the SP. The UUID of the service that the
notifications are for are stored in X5/X6 registers shown above.

The UUID for notification service is
{B510B3A3-59F6-4054-BA7A-FF2EB1EAC765} which is stored in X2/X3.

#### Notification Events

All notification events sent from all secure partitions are passed back
through the FFA driver. The notification calls the _DSM method. Function 0
is always a bitmap of all the other functions supported. We must support at
least a minium of the Query and Notify.
The UUID is stored in Arg0 and the notification cookie is stored in Arg3 when Arg2 is 11.
```rust
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
        Store(Index(Arg3,1), \_SB.ECT0.NEVT )
        Return(Zero) 
      }
    } Else {
      Return(Buffer(One) { 0x00 })
    }
  }
```

The following is the call flow showing a secure interrupt arriving to
the EC service which results in a notification back to ACPI. The
notification payload can optionally be written to a shared buffer or
ACPI can make another call back into EC service to retrieve the
notification details.

The _NFY only contains the ID of the notification and no other payload,
so both ACPI and the EC service must be designed either with shared
memory buffer or a further notify data packet.

![A diagram of a service Description automatically
generated](media/image3.png)

## Runtime Requests

During runtime the non-secure side uses FFA_MSG_SEND_DIRECT_REQ2
requests to send requests to a given service within an SP. Any request
that is expected to take longer than 500 uSec should yield control back
to the OS by calling FFA_YIELD within the service. When FFA_YIELD is
called it will return control back to the OS to continue executing but
the corresponding ACPI thread will be blocked until the original FFA
request completes with DIRECT_RSP2. Note this creates a polling type
interface where the OS will resume the SP thread after the timeout
specified. The following is sample call sequence.

![A diagram of a company's process Description automatically
generated](media/image4.png)

### FFA Example Data Flow

For an example let’s take the battery status request _BST and follow
data through.

![A screenshot of a computer Description automatically
generated](media/image5.png)

```rust
FFA_REQ_PACKET req = {
  0x0, // Initialize to no error
  0x1, // Only 1 byte of data is sent after the header
  {0x25,0xcb,0x52,0x07,0xac,0x36,0x42,0x7d,0xaa,0xef,0x3a,0xa7,0x88,0x77,0xd2,0x7e},
  0x2 // EC_BAT_GET_BST
}
```

The equivalent to write this data into a BUFF in ACPI is as follows

```rust
Name(BUFF, Buffer(32){}) // Create buffer for send/recv data
CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
CreateField(BUFF,16,128,UUID) // UUID of service
CreateByteField(BUFF,18, CMDD) // In – First byte of command
CreateField(BUFF,144,128,BSTD) // Out – Raw data response 4 DWords
Store(20,LENG)
Store(0x2, CMDD)
Store(ToUUID ("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)
Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)
```

The ACPI interpreter when walking through this code creates a buffer and
populates the data into buffer. The last line indicates to send this
buffer over FFA interface.

ACPI calls into the FFA interface to send the data over to the secure
world EC Service

```
typedef struct _FFA_INTERFACE {
    ULONG Version;
    PFFA_MSG_SEND_DIRECT_REQ2 SendDirectReq2;
} FFA_INTERFACE, \*PFFA_INTERFACE;
````

### FFA Parsing

FFA is in charge of sending the SMC over to the secure world and routing
to the correct service based on UUID.

![A diagram of a computer Description automatically
generated](media/image6.png)

```
X0 = SEND_DIRECT_REQ2 SMC command ID
X1 = Source ID and Destination ID
X2 = UUID Low
X3 = UUID High
X4-X17 = rawdata
```

**Note:** The status and length are not passed through to the secure
world they are consumed only be ACPI.

HyperV and Monitor have a chance to filter or deny the request, but in
general just pass the SMC request through to Hafnium

Hafnium extracts the data from the registers into an sp_msg structure
which is directly mapping contents from x0-x17 into these fields.

```rust
pub struct FfaParams {
    pub x0: u64,
    pub x1: u64,
    pub x2: u64,
    pub x3: u64,
    pub x4: u64,
    pub x5: u64,
    pub x6: u64,
    pub x7: u64,
    pub x8: u64,
    pub x9: u64,
    pub x10: u64,
    pub x11: u64,
    pub x12: u64,
    pub x13: u64,
    pub x14: u64,
    pub x15: u64,
    pub x16: u64,
    pub x17: u64,
}
```

In our SP we receive the raw FfaParams structure and we convert this to
an FfaMsg using our translator. This pulls out the function_id,
source_id, destination_id and uuid.

```rust
fn from(params: FfaParams) -> FfaMsg {
  FfaMsg {
    function_id: params.x0,              // Function id is in lower 32 bits of x0
    source_id: (params.x1 >> 16) as u16, // Source in upper 16 bits
    destination_id: params.x1 as u16,    // Destination in lower 16 bits
    uuid: u64_to_uuid(params.x2, params.x3),
    args64: [
      params.x4, params.x5, params.x6, params.x7, params.x8, params.x9, params.x10,
      params.x11, params.x12, params.x13, params.x14, params.x15, params.x16, params.x17,
            ],
  }
}
```

The destination_id is used to route the message to the correct SP, this
is based on the ID field in the DTS description file. Eg: id =
<0x8001>;

### EC Service Parsing

Within the EC partition there are several services that run, the routing
of the FF-A request to the correct services is done by the main message
handling loop for the secure partition. After receiving a message we
call into ffa_msg_handler and based on the UUID send it to the
corresponding service to handle the message.

```rust
let mut next_msg = ffa.msg_wait();
loop {
  match next_msg {
    Ok(ffamsg) => match ffa_msg_handler(&ffamsg) {
      Ok(msg) => next_msg = ffa.msg_resp(\&msg),
      Err(_e) => panic!("Failed to handle FFA msg"),
    },
    Err(_e) => {
      panic!("Error executing msg_wait");
    }
   }
}
```

The main message loop gets the response back from ffa_msg_handler and
returns to non-secure world so the next incoming message after the
response is a new message to handle.

```rust
fn ffa_msg_handler(msg: &FfaMsg) -> Result<FfaMsg> {
    println!(
        "Successfully received ffa msg:
        function_id = {:08x}
               uuid = {}",
        msg.function_id, msg.uuid
    );

    match msg.uuid {
        UUID_EC_SVC_MANAGEMENT => {
            let fwmgmt = fw_mgmt::FwMgmt::new();
            fwmgmt.exec(msg)
        }

        UUID_EC_SVC_NOTIFY => {
            let ntfy = notify::Notify::new();
            ntfy.exec(msg)
        }

        UUID_EC_SVC_POWER => {
            let pwr = power::Power::new();
            pwr.exec(msg)
        }

        UUID_EC_SVC_BATTERY => {
            let batt = battery::Battery::new();
            batt.exec(msg)
        }

        UUID_EC_SVC_THERMAL => {
            let thm = thermal::ThmMgmt::new();
            thm.exec(msg)
        }

        UUID_EC_SVC_UCSI => {
            let ucsi = ucsi::UCSI::new();
            ucsi.exec(msg)
        }

        UUID_EC_SVC_TIME_ALARM => {
            let alrm = alarm::Alarm::new();
            alrm.exec(msg)
        }

        UUID_EC_SVC_DEBUG => {
            let dbg = debug::Debug::new();
            dbg.exec(msg)
        }

        UUID_EC_SVC_OEM => {
            let oem = oem::OEM::new();
            oem.exec(msg)
        }

        _ => panic!("Unknown UUID"),
    }
}
```

### Large Data Transfers

When making an FFA_MSG_SEND_DIRECT_REQ2 call the data is stored in
registers X0-X17. X0-X3 are reserved to store the Function Id, Source
Id, Destination Id and UUID. This leaves X4-X17 or 112 bytes. For larger
messages they either need to be broken into multiple pieces or make use
of a shared buffer between the OS and Secure Partition.

#### Shared Buffer Definitions

To create a shared buffer you need to modify the dts file for the secure
partition to include mapping to your buffer.

```rust
ns_comm_buffer {
  description = "ns-comm";
  base-address = <0x00000100 0x60000000>;
  pages-count = <0x8>;
  attributes = <NON_SECURE_RW>;
};
```

During UEFI Platform initialization you will need to do the following
steps, see the FFA specification for more details on these commands

  - FFA_MAP_RXTX_BUFFER
  - FFA_MEM_SHARE
  - FFA_MSG_SEND_DIRECT_REQ2 (EC_CAP_MEM_SHARE)
  - FFA_UNMAP_RXTX_BUFFER

The RXTX buffer is used during larger packet transfers but can be
overridden and updated by the framework. The MEM_SHARE command uses the
RXTX buffer so we first map that buffer then populate our memory
descriptor requests to the TX_BUFFER and send to Hafnium. After sending
the MEM_SHARE request we need to instruct our SP to retrieve this
memory mapping request. This is done through our customer
EC_CAP_MEM_SHARE request where we describe the shared memory region
that UEFI has donated. From there we call FFA_MEM_RETRIEVE_REQ to map
the shared memory that was described to Hafnium. After we are done with
the RXTX buffers we must unmap them as the OS will re-map new RXTX
buffers. From this point on both Non-secure and Secure side will have
access to this shared memory buffer that was allocated.

### Async Transfers

All services are single threaded by default. Even when doing FFA_YIELD
it does not allow any new content to be executed within the service. If
you need your service to be truly asynchronous you must have commands
with delayed responses.

There is no packet identifier by default and tracking of requests and
completion by FFA, so the sample solution given here is based on shared
buffers defined in previous section and existing ACPI and FFA
functionality.

![A diagram of a service Description automatically
generated](media/image7.png)

Inside of our FFA functions rather than copying our data payload into
the direct registers we define a queue in shared memory and populate the
actual data into this queue entry. In the FFA_MSG_SEND_DIRECT_REQ2
we populate an ASYNC command ID (0x0) along with the seq \#. The seq \#
is then used by the service to locate the request in the TX queue. We
define a separate queue for RX and TX so we don’t need to synchronize
between OS and secure partition.

![](media/image8.png)

### ACPI Structures and Methods for Asynchronous

The SMTX is shared memory TX region definition

```rust
// Shared memory regions and ASYNC implementation
OperationRegion (SMTX, SystemMemory, 0x10060000000, 0x1000)

// Store our actual request to shared memory TX buffer
Field (SMTX, AnyAcc, NoLock, Preserve)
{
  TVER, 16,
  TCNT, 16,
  TRS0, 32,
  TB0, 64,
  TB1, 64,
  TB2, 64,
  TB3, 64,
  TB4, 64,
  TB5, 64,
  TB6, 64,
  TB7, 64,
  Offset(0x100), // First Entry starts at 256 byte offset each entry is 256 bytes
  TE0, 2048,
  TE1, 2048,
  TE2, 2048,
  TE3, 2048,
  TE4, 2048,
  TE5, 2048,
  TE6, 2048,
  TE7, 2048,
}
```

The QTXB method copies data into first available entry in the TX queue
and returns sequence number used.

```rust
// Arg0 is buffer pointer
// Arg1 is length of Data
// Return Seq \#
Method(QTXB, 0x2, Serialized) {
  Name(TBX, 0x0)
  Store(Add(ShiftLeft(1,32),Add(ShiftLeft(Arg1,16),SEQN)),TBX)
  Increment(SEQN)
  // Loop until we find a free entry to populate
  While(One) {
    If(LEqual(And(TB0,0xFFFF),0x0)) {
      Store(TBX,TB0); Store(Arg0,TE0); Return( And(TBX,0xFFFF) )
    }

    If(LEqual(And(TB1,0xFFFF),0x0)) {
      Store(TBX,TB1); Store(Arg0,TE1); Return( And(TBX,0xFFFF) )
    }

    If(LEqual(And(TB2,0xFFFF),0x0)) {
      Store(TBX,TB2); Store(Arg0,TE2); Return( And(TBX,0xFFFF) )
    }

    If(LEqual(And(TB3,0xFFFF),0x0)) {
      Store(TBX,TB3); Store(Arg0,TE3); Return( And(TBX,0xFFFF) )
    }

    If(LEqual(And(TB4,0xFFFF),0x0)) {
      Store(TBX,TB4); Store(Arg0,TE4); Return( And(TBX,0xFFFF) )
    }

    If(LEqual(And(TB5,0xFFFF),0x0)) {
      Store(TBX,TB5); Store(Arg0,TE5); Return( And(TBX,0xFFFF) )
    }

    If(LEqual(And(TB6,0xFFFF),0x0)) {
      Store(TBX,TB6); Store(Arg0,TE6); Return( And(TBX,0xFFFF) )
    }

    If(LEqual(And(TB7,0xFFFF),0x0)) {
      Store(TBX,TB7); Store(Arg0,TE7); Return( And(TBX,0xFFFF) )
    }

    Sleep(5)
  }
}
```

The SMRX is shared memory region for RX queues

```rust
// Shared memory region
OperationRegion (SMRX, SystemMemory, 0x10060001000, 0x1000)

// Store our actual request to shared memory TX buffer
Field (SMRX, AnyAcc, NoLock, Preserve)
{
  RVER, 16,
  RCNT, 16,
  RRS0, 32,
  RB0, 64,
  RB1, 64,
  RB2, 64,
  RB3, 64,
  RB4, 64,
  RB5, 64,
  RB6, 64,
  RB7, 64,
  Offset(0x100), // First Entry starts at 256 byte offset each entry is 256 bytes
  RE0, 2048,
  RE1, 2048,
  RE2, 2048,
  RE3, 2048,
  RE4, 2048,
  RE5, 2048,
  RE6, 2048,
  RE7, 2048,
}
```

The RXDB function takes sequence number as input and will keep looping
through all the entries until we see packet has completed. Sleeps for
5ms between each iteration to allow the OS to do other things and other
ACPI threads can run.

```rust
// Allow multiple threads to wait for their SEQ packet at once
// If supporting packet \> 256 bytes need to modify to stitch together packet
Method(RXDB, 0x1, Serialized) {
  Name(BUFF, Buffer(256){})
  // Loop forever until we find our seq
  While (One) {
    If(LEqual(And(RB0,0xFFFF),Arg0)) {
      CreateField(BUFF, 0, Multiply(And(ShiftRight(RB0,16),0xFFFF),8), XB0)
      Store(RE0,BUFF); Store(0,RB0); Return( XB0 )
    }

    If(LEqual(And(RB1,0xFFFF),Arg0)) {
      CreateField(BUFF, 0, Multiply(And(ShiftRight(RB1,16),0xFFFF),8), XB1)
      Store(RE1,BUFF); Store(0,RB1); Return( XB1 )
    }

    If(LEqual(And(RB2,0xFFFF),Arg0)) {
      CreateField(BUFF, 0, Multiply(And(ShiftRight(RB2,16),0xFFFF),8), XB2)
      Store(RE2,BUFF); Store(0,RB2); Return( XB2 )
    }

    If(LEqual(And(RB3,0xFFFF),Arg0)) {
      CreateField(BUFF, 0, Multiply(And(ShiftRight(RB3,16),0xFFFF),8), XB3)
      Store(RE3,BUFF); Store(0,RB3); Return( XB3 )
    }

    If(LEqual(And(RB4,0xFFFF),Arg0)) {
      CreateField(BUFF, 0, Multiply(And(ShiftRight(RB4,16),0xFFFF),8), XB4)
      Store(RE4,BUFF); Store(0,RB4); Return( XB4 )
    }

    If(LEqual(And(RB5,0xFFFF),Arg0)) {
      CreateField(BUFF, 0, Multiply(And(ShiftRight(RB5,16),0xFFFF),8), XB5)
      Store(RE5,BUFF); Store(0,RB5); Return( XB5 )
    }

    If(LEqual(And(RB6,0xFFFF),Arg0)) {
      CreateField(BUFF, 0, Multiply(And(ShiftRight(RB6,16),0xFFFF),8), XB6)
      Store(RE6,BUFF); Store(0,RB6); Return( XB6 )
    }

    If(LEqual(And(RB7,0xFFFF),Arg0)) {
      CreateField(BUFF, 0, Multiply(And(ShiftRight(RB7,16),0xFFFF),8), XB7)
      Store(RE7,BUFF); Store(0,RB7); Return( XB7 )
    }

    Sleep(5)
  }

  // If we get here didn't find a matching sequence number
  Return (Ones)
}
```

The following is sample code to transmit a ASYNC request and wait for
the data in the RX buffer.

```rust
Method(ASYC, 0x0, Serialized) {
  If(LEqual(\\_SB.FFA0.AVAL,One)) {
  Name(BUFF, Buffer(30){})
  CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
  CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
  CreateField(BUFF,16,128,UUID) // UUID of service
  CreateByteField(BUFF,18,CMDD) // Command register
  CreateWordField(BUFF,19,BSQN) // Sequence Number

  // x0 -\> STAT
  Store(20, LENG)
  Store(0x0, CMDD) // EC_ASYNC command
  Local0 = QTXB(BUFF,20) // Copy data to our queue entry and get back SEQN
  Store(Local0,BSQN) // Sequence packet to read from shared memory
  Store(ToUUID("330c1273-fde5-4757-9819-5b6539037502"), UUID)
  Store(Store(BUFF, \\_SB_.FFA0.FFAC), BUFF)

  If(LEqual(STAT,0x0) ) // Check FF-A successful?
  {
    Return (RXDB(Local0)) // Loop through our RX queue till packet completes
  }
}
```

## Recovery and Errors

The eSPI or bus driver is expected to detect if the EC is not responding
and retry. The FFA driver will report back in the status byte if it
cannot successfully talk to the secure world. If there are other
failures generally they should be returned back up through ACPI with a
value of (Ones) to indicate failure condition. This may cause some
features to work incorrectly.

It is also expected that the EC has a watchdog if something on the EC is
hung it should reset and reload on its own. The EC is also responsible
for monitoring that the system is running within safe parameters. The
thermal requests and queries are meant to be advisory in nature and EC
should be able to run independently and safely without any intervention
from the OS.
