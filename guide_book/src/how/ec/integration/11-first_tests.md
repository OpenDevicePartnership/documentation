# First Tests

Now let's go back to `entry.rs` and add a few more imports we will need:
```rust
use embassy_executor::Spawner;
use crate::display_models::Thresholds;
use mock_battery::virtual_battery::VirtualBatteryState;
use crate::events::RenderMode;
use crate::events::DisplayEvent;
use crate::events::InteractionEvent;
use crate::system_observer::SystemObserver;
// use crate::display_render::display_render::DisplayRenderer;

// Task imports
use crate::setup_and_tap::setup_and_tap_task;

```
And now we want to add the entry point that is called by `main()` here (in `entry.rs`):
```rust
#[embassy_executor::task]
pub async fn entry_task_interactive(spawner: Spawner) {
    println!("🚀 Interactive mode: integration project");
    let shared = init_shared();
 
    println!("setup_and_tap_starting");
    let battery_ready = shared.battery_ready;
    spawner.spawn(setup_and_tap_task(spawner, shared)).unwrap();
    battery_ready.wait().await;
    println!("init complete");

    // spawner.spawn(interaction_task(shared.interaction_channel)).unwrap();
    // spawner.spawn(render_task(shared.display_channel)).unwrap();

}
```
Now we need to create and connect the `SystemObserver` within `entry.rs`.  

Below the other static allocations, add this line:
```rust

static SYS_OBS: StaticCell<SystemObserver> = StaticCell::new();

```
Uncomment this line to expose the observer property we are about to create
```rust
pub struct Shared {
    // pub observer: &'static SystemObserver,
    pub battery_channel: &'static BatteryChannelWrapper,
```
and uncomment the creation of this in `init_shared()`:
```rust
    // let observer = SYS_OBS.init(SystemObserver::new(
    //     Thresholds::new(),
    //     v_nominal_mv,
    //     display_channel
    // ));
```
as well as the reference to `observer` in the creation of `Shared` below that:
```rust
    SHARED.get_or_init(|| SHARED_CELL.init(Shared {
        // observer,
        battery_channel,
```

Great! We are almost ready for our first test run.  We just need to add some start up tasks to complete the work
in `setup_and_tap.rs`:

Add these tasks:
```rust
// this will move ownership of ControllerTap to the battery_service, which will utilize the battery traits
// to call messages that we intercept ('tap') and thus can access the other components for messaging and simulation.
#[embassy_executor::task]
pub async fn battery_wrapper_task(wrapper: &'static mut Wrapper<'static, BatteryAdapter>) {
    wrapper.process().await;
}

#[embassy_executor::task]
pub async fn battery_start_task() {
    use battery_service::context::{BatteryEvent, BatteryEventInner};
    use battery_service::device::DeviceId;

    println!("🥺 Doing battery service startup -- DoInit followed by PollDynamicData");

    // 1) initialize (this will Ping + UpdateStaticCache, then move to Polling)
    let init_resp = battery_service::execute_event(BatteryEvent {
        device_id: DeviceId(BATTERY_DEV_NUM),
        event: BatteryEventInner::DoInit,
    }).await;

    println!("battery-service DoInit -> {:?}", init_resp);

    // 2) get Static data first
    let static_resp = battery_service::execute_event(BatteryEvent {
        device_id: DeviceId(BATTERY_DEV_NUM),
        event: BatteryEventInner::PollStaticData,
    }).await;
    if static_resp.is_err() {
        eprintln!("Polling loop PollStaticData call to battery service failure!");
    }

    let delay:Duration = Duration::from_secs(3);
    let interval:Duration = Duration::from_millis(250);
    
    embassy_time::Timer::after(delay).await;

    loop {
        // 3) now poll dynamic (valid only in Polling)
        let dyn_resp = battery_service::execute_event(BatteryEvent {
            device_id: DeviceId(BATTERY_DEV_NUM),
            event: BatteryEventInner::PollDynamicData,
        }).await;
        if let Err(e) = &dyn_resp {
            eprintln!("Polling loop PollDynamicData call to battery service failure! (pretty) {e:#?}");
        }
        embassy_time::Timer::after(interval).await;
    }

}
```
Starting the `battery_wrapper_task` is what binds our battery controller to the battery-service where it awaits command messages to begin its orchestration. We kick this off in `battery_start_task` by giving it the expected sequence of starting messages, placing it into the _polling_ mode where we can continue the pump to receive repeated dynamic data reports.

### Including modules
If you haven't already, be sure to include the new modules in `main.rs`.  The set of modules named here should include:
```rust
mod config;
mod policy;
mod model;
mod state;
mod events;
mod entry;
mod setup_and_tap;
mod controller_core;
mod display_models;
mod battery_adapter;
mod system_observer;
```


At this point, you should be able to do a `cargo check` and get a successful build without errors -- you'll get a lot of warnings because there are a number of unused imports and references we haven't attached yet, but you can ignore those for now.

If you run the program with `cargo run`, you should see this output:
```
🚀 Interactive mode: integration project
setup_and_tap_starting
⚙️ Initializing embedded-services
⚙️ Spawning battery service task
⚙️ Spawning battery wrapper task
🥳 >>>>> get_timeout has been called!!! <<<<<<
🧩 Registering battery device...
🧩 Registering charger device...
🧩 Registering sensor device to thermal service...
🧩 Registering fan device to thermal service...
🔌 Initializing battery fuel gauge service...
Setup and Tap calling ControllerCore::start...
In ControllerCore::start (fn=0x7ff6425f9860)
spawning charger_policy_event_task
spawning controller_core_task
spawning start_charger_task
spawning integration_listener_task
init complete
🥺 Doing battery service startup -- DoInit followed by PollDynamicData
✅ Charger is ready.
🥳 >>>>> get_timeout has been called!!! <<<<<<
🥳 >>>>> ping has been called!!! <<<<<<
🛠️  Charger initialized.
🥳 >>>>> get_timeout has been called!!! <<<<<<
battery-service DoInit -> Ok(Ack)
🥳 >>>>> get_timeout has been called!!! <<<<<<
🥳 >>>>> get_static_data has been called!!! <<<<<<
🥳 >>>>> get_timeout has been called!!! <<<<<<
🥳 >>>>> get_dynamic_data has been called!!! <<<<<<
🥳 >>>>> get_timeout has been called!!! <<<<<<
🥳 >>>>> get_dynamic_data has been called!!! <<<<<<
```
with the last few lines repeating endlessly.  Press `ctrl-c` to exit.

Congratulations! This means that the scaffolding is all in place and ready for the continuation of the implementation.

Let's pause here to review what is actually happening at this point.

### Review of operation so far
1. `main()` calls `entry_task_interactive()`, which initializes the shared handles and spawns the `setup_and_tap_task()`.
2. `setup_and_tap_task()` initializes embedded-services, and thermal-services, spawns the battery service task, constructs and registers the mock devices and controllers, registers the thermal components, and finally spawns the `ControllerCore::start()` task.
3. `ControllerCore::start()` initializes the controller core, spawns the charger policy event task, the controller core task, the start charger task, and the integration listener task.
4. Meanwhile, back in `entry_task_interactive()`, after spawning `setup_and_tap_task()`, it waits for the battery fuel service to signal that it is ready, which happens at the end of `setup_and_tap_task()`.
5. The `battery_start_task()` is spawned as part of `setup_and_tap_task ()`, which initializes the battery service by sending it a `DoInit` event, followed by a `PollStaticData` event, and then enters a loop where it continuously sends `PollDynamicData` events to the battery service at regular intervals.   This is what drives the periodic updates of battery data in our integration.        
6. The battery service, upon receiving the `DoInit` event, calls the `ping()` and `get_timeout()` methods of our `BatteryAdapter`, which in turn call into the `ControllerCore` to handle these requests.  The battery service then transitions to the polling state.
7. The `PollStaticData` and `PollDynamicData` events similarly call into the `BatteryAdapter`, which forwards these calls to the `ControllerCore`, which will eventually handle these requests and return the appropriate data to the battery service.
8. The `ControllerCore` also has tasks running that listen for charger policy events and other integration events, although these are not yet fully implemented.

As we see here, the operational flow is driven through the battery service's polling mechanism, where we we tap the `get_dynamic_data()` calls to access the `ControllerCore` and shared comm channels to facilitate the integration of the various components to work together.

To do that, we will next implement the listeners and handlers within the ControllerCore to respond to these calls and to manage the interactions between the battery, charger, sensor, and fan components.

