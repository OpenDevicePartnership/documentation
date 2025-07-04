# Battery Event Messaging

So far we have constructed a flow that can send a BatteryEvent message as a test, but there's nothing handling it.

You may recall our `EspiService` has an empty `receive` function for its `MailboxDelegate`.

We are sending a `PollStaticData` event for our test message.  But the `EspiService` code can't reasonably respond to that because

1. It is not aware of the `MockBatteryController`.
2. Even if it was, the `Controller` functions are all async, and `EspiService` operates from a synchronous context.

## Open a Channel

What `EspiService` _can_ do, however, is to route messages on to an asynchronous message queue called a `Channel`.  
Then an event handler spawned as one of our main tasks can read from this queue and process the messages it receives.


What we will do in the next few steps:

1. Define a `Channel` owned by the main process that is sent into `EspiService` for routing
2. Listen to this channel for BatteryEvent messages and process them
3. Route messages sent via `EspiService` to the correct channel.

### Creating the channel and the listener

Let's first define a channel type for our BatteryEvent messages.

We'll put this into a separate `types.rs` file so that it is available in more than one place. We can add other type definitions to this later, also:

```rust
// mock_battery/src/types.rs

use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::channel::Channel;
use battery_service::context::BatteryEvent;

pub type BatteryChannel = Channel<ThreadModeRawMutex, BatteryEvent, 4>;
```
and add this to `lib.rs`

```rust
pub mod mock_battery;
pub mod virtual_battery;
pub mod mock_battery_device;
pub mod espi_service;
pub mod mock_battery_controller;
pub mod types;
```

Now, in our `main.rs` file, add these imports:

```rust
use mock_battery::types::BatteryChannel;
use embassy_sync::channel::Channel;
use battery_service::controller::Controller;
```

and down below, along with the other static allocations, add:
```rust
static BATTERY_EVENT_CHANNEL: StaticCell<BatteryChannel> = StaticCell::new();
```

Then create `init` and `get` references to it in our `main()`. 
We'll need one for passing to our `EspiService` and one for our event handler task.
We will also need another copy of our controller reference to send to the event handler task.

```rust
    let battery_channel = BATTERY_EVENT_CHANNEL.init(Channel::new());
    let battery_channel_for_handler = unsafe { &mut *(battery_channel as *const _ as *mut _) };
    let controller_for_handler = unsafe { &mut *(controller as *const _ as *mut _) };
```
Let's go ahead and call the spawns for these tasks now in the `run()` spawn list:
```rust
    executor.run(|spawner| {
        spawner.spawn(init_task(battery)).unwrap();
        spawner.spawn(battery_service::task()).unwrap();
        spawner.spawn(battery_service_init_task(fuel, battery_fuel_ready)).unwrap();
        spawner.spawn(time_driver::run()). unwrap();
        spawner.spawn(espi_service_init_task (battery_channel)).unwrap();
        spawner.spawn(wrapper_task_launcher(fuel_for_controller, controller, battery_fuel_ready, spawner)).unwrap();
        spawner.spawn(event_handler_task(controller_for_handler, battery_channel_for_handler)).unwrap();
    });

```

Update the `espi_service_init_task` to accept this parameter:
```rust
#[embassy_executor::task]
async fn espi_service_init_task(battery_channel: &'static mut BatteryChannel) {
    espi_service::init(battery_channel).await;
}
```
and create the new `event_handler_task` as thus:
```rust
#[embassy_executor::task]
async fn event_handler_task(
    mut controller: &'static mut MockBatteryController<&'static mut MockBattery>,
    channel: &'static mut BatteryChannel
) {
    use battery_service::context::BatteryEventInner;

    println!("🛠️  Starting event handler...");

    loop {
        let event = channel.receive().await;
        println!("🔔 event_handler_task received event: {:?}", event);
        match event.event {
            BatteryEventInner::PollStaticData => {
                println!("🔄 Handling PollStaticData");
                let _ = controller.get_static_data().await;
            }
            BatteryEventInner::PollDynamicData => {
                println!("🔄 Handling PollDynamicData");
            }
            BatteryEventInner::DoInit => {
                println!("⚙️  Handling DoInit");
            }
            BatteryEventInner::Oem(code, data) => {
                println!("🧩 Handling OEM command: code = {code}, data = {:?}", data);
            }
            BatteryEventInner::Timeout => {
                println!("⏰ Timeout event received");
            }
        }
    }
}
```


Now, to update `espi_service.rs`:

Update these sections of your current `espi_service.rs` code to match each of these blocks where they occur:

```rust
use battery_service::context::{BatteryEvent, BatteryEventInner};
use battery_service::device::DeviceId;
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::signal::Signal;
use embedded_services::comms::{self, EndpointID, Internal, MailboxDelegate, MailboxDelegateError, Message};

use core::sync::atomic::{AtomicBool, Ordering};
use static_cell::StaticCell;

use crate::types::BatteryChannel;

pub struct EspiService {
    pub endpoint: comms::Endpoint,
    battery_channel: &'static mut BatteryChannel,
    _signal: Signal<ThreadModeRawMutex, BatteryEvent>
}
impl EspiService {
    pub fn new(battery_channel: &'static mut BatteryChannel) -> Self {
        Self {
            endpoint: comms::Endpoint::uninit(EndpointID::Internal(Internal::Battery)),
            battery_channel,
            _signal: Signal::new(),
        }
    }
}

// Forward BatteryEvent messages to the channel
impl MailboxDelegate for EspiService {
    fn receive(&self, message: &Message) -> Result<(), MailboxDelegateError> {
        println!("📬 EspiService received message: {:?}", message);
        let event = message
            .data
            .get::<BatteryEvent>()
            .ok_or(MailboxDelegateError::MessageNotFound)?;

        // Forward the event to the battery channel    
        self.battery_channel.try_send(*event).unwrap(); // replace .unwrap() with proper error handling if desired
        Ok(())
    }
}

/// Initialize the ESPI service with the passed-in channel reference
pub async fn init(battery_channel: &'static mut BatteryChannel) {
    println!("🔌 EspiService init()");
    let svc = INSTANCE.init(EspiService::new(battery_channel));

    // ...

```
With these updates, you should be able to run and see this output:

```
🛠️  Starting event handler...
🔄 Launching wrapper task...
🔌 EspiService init()
🧩 Registering ESPI service endpoint...
🕒 time_driver started
🔌 Initializing battery fuel gauge service...
🔋 Launching battery service (single-threaded)
🧩 Registering battery device...
✅🔋 Battery service is up and running.
✅🔌 EspiService READY
🔔 BATTERY_FUEL_READY signaled
✍ Sending test BatteryEvent...
📬 EspiService received message: Message { from: Internal(Battery), to: Internal(Battery), data: Data { contents: Any { .. } } }
✅ Test BatteryEvent sent
🔔 event_handler_task received event: BatteryEvent { event: PollStaticData, device_id: DeviceId(1) }
🔄 Handling PollStaticData
```

We have everything in place, and although we're still not doing anything with the message we receive, we can see that our event handler is indeed receiving it.

Next we will start the steps for handling the data.