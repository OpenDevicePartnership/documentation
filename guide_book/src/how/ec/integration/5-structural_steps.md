# The Structural Steps of our new Integration
Before we start implementing, it is worth setting the overview and expectations for how we will bring up this new integrated scaffolding.

Like most applications, ours starts with the `main()` function.  In deference to a later targeting to an embedded build, we will mark this as an `#[embassy_executor::main]`, which saves us the trouble of spinning up our own instance of embassy-executor in order to spawn our tasks.  Nevertheless, the `main()` function's only job here is to spin up the `entry_task_interactive` start point (later, we'll have a separate, similar entry point for test mode).

Put this content into your `main.rs`:

```rust

use embassy_executor::Spawner;

mod config;
mod policy;
mod model;
mod state;
mod events;
mod entry;
mod setup_and_tap;
mod controller_core;

#[embassy_executor::main]
async fn main(spawner: Spawner) {

    spawner.spawn(entry::entry_task_interactive(spawner)).unwrap();
}
```

note the `mod` lines here that bring in the configuration definitions we constructed previously, as well as our new consolidated local `events.rs`. This is similar to what we did using `lib.rs` in previous examples, but since this is a singular app and not a crate, per-se, we will use `main.rs` as the aggregation point for external files to include.

You will see that in addition to the configuration files we have already created, we also make reference to the following:
- `entry`
- `setup_and_tap`
- `controller_core`

You can go ahead and create these files in `src` (`entry.rs`, `setup_and_tap.rs`, `controller_core.rs`) and leave them empty for now, as we will be filling them out in the next few steps.

First, let's explain what we have in mind for each of them:

We will place our `entry_task_interactive` in a new file we create named `entry.rs`, which we will construct in a moment.  This file will be responsible mostly for allocation of our components and the definition of our new comm "channels".

Next in line for the startup of our scaffolding is contained in a file we will name `setup_and_tap.rs`. This file is responsible for initializing the components and the services. The `tap` part of its name comes from the nature of how we interface with the Battery service inherent in `embedded-services`.  As we noted earlier, in previous exercises, we prepared for using this service, but never actually did use it, and therefore needed to do much of our own event wiring rather than adhere to the default event sequence ODP provides for us.  To actually use it, we must give ownership of our BatteryController to the service, and use the callbacks into the trait methods invoked by messages to gain access to our wider integrated scope (hence `tap`ping into it). 
Our _"wider integrated scope"_ is represented by `controller_core.rs` where we will implement the required traits necessary for a `Battery` Controller so that we can give it to the Battery service, while keeping all of our actual components held close as member properties.  This allows us to treat the integration as a unified whole without breaking ownership rules.

## The beginnings of entry.rs

`entry.rs` defines the thin wrappers we put around our new comm Channel implementations (replacing `EspiService`), and it establishes the static residence for many of our top-level components.

Let's start it out with this content: 
```rust
use static_cell::StaticCell;

use embassy_sync::channel::Channel;
use embassy_sync::once_lock::OnceLock;

use ec_common::mutex::RawMutex;
use ec_common::espi_service::{
    EventChannel, MailboxDelegateError
};
use ec_common::fuel_signal_ready::BatteryFuelReadySignal;
use ec_common::events::ThermalEvent;

use battery_service::context::BatteryEvent;
use battery_service::device::{Device as BatteryDevice, DeviceId as BatteryServiceDeviceId};

use embedded_services::power::policy::charger::ChargerEvent;

pub const BATTERY_DEV_NUM: u8 = 1;
pub const CHARGER_DEV_NUM: u8 = 2;
pub const SENSOR_DEV_NUM:  u8 = 3;
pub const FAN_DEV_NUM:     u8 = 4;


// ---------- Channels as thin wrappers ----------
const CHANNEL_CAPACITY:usize = 16;

pub struct BatteryChannelWrapper(pub Channel<RawMutex, BatteryEvent, CHANNEL_CAPACITY>);
#[allow(unused)]
impl BatteryChannelWrapper {
    pub async fn send(&self, e: BatteryEvent) { self.0.send(e).await }
    pub async fn receive(&self) -> BatteryEvent { self.0.receive().await }
}
impl EventChannel for BatteryChannelWrapper {
    type Event = BatteryEvent;
    fn try_send(&self, e: BatteryEvent) -> Result<(), MailboxDelegateError> {
        self.0.try_send(e).map_err(|_| MailboxDelegateError::MessageNotFound)
    }
}
pub struct ChargerChannelWrapper(pub Channel<RawMutex, ChargerEvent, CHANNEL_CAPACITY>);
impl EventChannel for ChargerChannelWrapper {
    type Event = ChargerEvent;
    fn try_send(&self, e: ChargerEvent) -> Result<(), MailboxDelegateError> {
        self.0.try_send(e).map_err(|_| MailboxDelegateError::MessageNotFound)
    }
}
pub struct ThermalChannelWrapper(pub Channel<RawMutex, ThermalEvent, CHANNEL_CAPACITY>);
impl EventChannel for ThermalChannelWrapper {
    type Event = ThermalEvent;
    fn try_send(&self, e: ThermalEvent) -> Result<(), MailboxDelegateError> {
        self.0.try_send(e).map_err(|_| MailboxDelegateError::MessageNotFound)
    }
}
pub struct DisplayChannelWrapper(pub Channel<RawMutex, DisplayEvent, CHANNEL_CAPACITY>);
#[allow(unused)]
impl DisplayChannelWrapper {
    pub async fn send(&self, e: DisplayEvent) { self.0.send(e).await }
    pub async fn receive(&self) -> DisplayEvent { self.0.receive().await }
}
impl EventChannel for DisplayChannelWrapper {
    type Event = DisplayEvent;
    fn try_send(&self, e: DisplayEvent) -> Result<(), MailboxDelegateError> {
        self.0.try_send(e).map_err(|_| MailboxDelegateError::MessageNotFound)
    }
}
pub struct InteractionChannelWrapper(pub Channel<RawMutex, InteractionEvent, CHANNEL_CAPACITY>);
impl InteractionChannelWrapper {
    pub async fn send(&self, e: InteractionEvent) { self.0.send(e).await }
    pub async fn receive(&self) -> InteractionEvent { self.0.receive().await }
}
impl EventChannel for InteractionChannelWrapper {
    type Event = InteractionEvent;
    fn try_send(&self, e: InteractionEvent) -> Result<(), MailboxDelegateError> {
        self.0.try_send(e).map_err(|_| MailboxDelegateError::MessageNotFound)
    }
}

// ---------- Statics ----------
// Keep StaticCell for things that truly need &'static mut (exclusive owner)
static BATTERY_FUEL: StaticCell<BatteryDevice> = StaticCell::new();

// Channels + ready via OnceLock (immutable access pattern)
static BATTERY_FUEL_READY:    OnceLock<BatteryFuelReadySignal>  = OnceLock::new();

static BATTERY_EVENT_CHANNEL: OnceLock<BatteryChannelWrapper> = OnceLock::new();
static CHARGER_EVENT_CHANNEL: OnceLock<ChargerChannelWrapper>   = OnceLock::new();
static THERMAL_EVENT_CHANNEL: OnceLock<ThermalChannelWrapper>   = OnceLock::new();
static DISPLAY_EVENT_CHANNEL: OnceLock<DisplayChannelWrapper>   = OnceLock::new();
static INTERACTION_EVENT_CHANNEL: OnceLock<InteractionChannelWrapper> = OnceLock::new();

```
We still want the BATTERY_FUEL_READY signal that we used in previous integrations.  This tells us when the battery service is fully ready and we are safe to move ahead with other task activity.

Even though we have chosen to unify the channel handling, we still want to create separate addressable channel wrappers that include their own unique Event types for sending.  We define channels for each of our components, but also for the actions delegated to the Display and user input interaction.

One may note that the `try_send` method of the channel wrapper code above does not handle errors particularly well.
It is assumed in this simple implementation that the channel is available and never fills up (capacity = 16).  A more defensive strategy would check for back-pressure on the channel and throttle messaging appropriately.  Keep this in mind when implementing real-world scenarios.
 

## Introducing the UI
At this point in the setup of the scaffolding we should introduce the elements that make up the User Interface portion of our simulation.
As we outlined at the beginning of this exercise, we are seeking to make this integration run as an interactive simulation, a non-interactive simulation, and an integration test as well.

We will focus first on the simulation app aspects before considering our integration test implementation.

To implement our UI, we introduce a `SystemObserver`, an intermediary between the simulation and the UI, including handling the rendering.

Our rendering will assume two forms:  We'll support a conventional "Logging" output that simply prints lines in sequence to the console as the values occur, because this is useful for analysis and debugging of behavior over time.  But we will also support ANSI terminal cursor coding to support an "in-place" display that presents more of a dashboard view with changing values.  This makes evaluation of the overall behavior and "feel" of our simulation and its behavior a little more approachable.
Don't worry, we won't spend a lot of time on UI design or implementation techniques - just drop in code that will make for a easier to use interface.

Our simulation will also be interactive, allowing us to simulate increasing and decreasing load on the system, as one might experience during use of a typical laptop computer.

So let's get to it.  First, we'll define those values we wish to be displayed by the UI.

Create the file `display_models.rs` and give it this content to start:

```rust
#[derive(Clone, Debug)]
/// Static values that are displayed
pub struct StaticValues {
    /// Battery manufacturer name
    pub battery_mfr: String,
    /// Battery model name
    pub battery_name: String,
    /// Battery chemistry type (e.g. LION)
    pub battery_chem: String,
    /// Battery serial number
    pub battery_serial: String,
    /// Battery designed mW capacity
    pub battery_dsgn_cap_mwh: u32,
    /// Battery designed mV capacity
    pub battery_dsgn_voltage_mv: u16,
}
impl StaticValues {
    pub fn new() -> Self {
        Self {
            battery_mfr: String::new(),
            battery_name: String::new(),
            battery_chem: String::new(),
            battery_serial: String::new(),
            battery_dsgn_cap_mwh: 0,
            battery_dsgn_voltage_mv: 0,
        }
    }
}

#[derive(Clone, Debug)]
/// Properties that are displayed by the renderer
pub struct DisplayValues {
    /// Current running time of simulator (milliseconds)
    pub sim_time_ms: f32,
    /// Percent of State of Charge
    pub soc_percent: f32,  
    /// battery/sensor temperature (Celsius)
    pub temp_c: f32, 
    /// Fan running RPM
    pub fan_rpm: u16, 

    /// Current draw from system load (mA)
    pub load_ma: u16, 
    /// Charger input (mA)        
    pub charger_ma: u16,
    /// net difference to battery
    pub net_batt_ma: i16,     

    /// System draw in watts
    pub draw_watts: f32,
    /// System charge in watts
    pub charge_watts: f32, 
    /// Net difference in watts
    pub net_watts: f32      
}

impl DisplayValues {
    pub fn new() -> Self {
        Self {
            sim_time_ms: 0.0,
            soc_percent: 0.0,
            temp_c: 0.0,
            fan_rpm: 0,

            load_ma: 0,
            charger_ma: 0,
            net_batt_ma: 0,
            draw_watts: 0.0,
            charge_watts: 0.0,
            net_watts: 0.0
        }
    }
}
```
This set of structures defines both the static and dynamic values of the system that will be tracked and displayed.

These values pair up with the other configuration values we've already defined.

Now let's move on with starting to build the scaffolding that supports all of this.
