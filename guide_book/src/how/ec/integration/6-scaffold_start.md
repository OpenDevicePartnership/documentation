# Scaffolding start-up
The `main()` function of our program immediately calls into the task `entry_task_interactive`, which is where the true entry to our integration app gets underway.  

We need to instantiate the various parts of our integration.  This includes the parts that make up the scaffolding of the integration itself, such as the comm channels that carry component messages, and the parts responsible for display of data, and for user interaction. We did some of that in the previous step, in the first parts of `entry.rs`.

The integration scaffolding of course also includes the integrated components themselves.  The components will be managed together in a structure we will call `ComponentCore`.  This core will be independent of the display and interaction mechanics, which will be handled primarily by a structure we will call `SystemObserver`.

We will set about defining `ComponentCore` and `SystemObserver` shortly, but for now, we will concentrate on finishing out our basic scaffolding.

## Shared items
We can group and share some of the common elements in a collection we will called `Shared`.  This includes
the various comm `Channels` we have defined, and it will also hold the reference to our `SystemObserver` when we introduce that later.

Add the following to `entry.rs`:

```rust
// ---------- Shared handles for both modes ----------
// Shared, Sync-clean. This can safely sit in a static OnceLock<&'static Shared>.
pub struct Shared {
    // pub observer: &'static SystemObserver,
    pub battery_channel: &'static BatteryChannelWrapper,
    pub charger_channel: &'static ChargerChannelWrapper,
    pub thermal_channel: &'static ThermalChannelWrapper,
    pub display_channel: &'static DisplayChannelWrapper,
    pub interaction_channel: &'static InteractionChannelWrapper,
    pub battery_ready: &'static BatteryFuelReadySignal,
    pub battery_fuel: &'static BatteryDevice,
}

static SHARED_CELL: StaticCell<Shared> = StaticCell::new();
static SHARED: OnceLock<&'static Shared> = OnceLock::new();

fn init_shared() -> &'static Shared {
    // Channels + ready
    let battery_channel = BATTERY_EVENT_CHANNEL.get_or_init(|| BatteryChannelWrapper(Channel::new()));
    let charger_channel = CHARGER_EVENT_CHANNEL.get_or_init(|| ChargerChannelWrapper(Channel::new()));
    let thermal_channel = THERMAL_EVENT_CHANNEL.get_or_init(|| ThermalChannelWrapper(Channel::new()));
    let display_channel = DISPLAY_EVENT_CHANNEL.get_or_init(|| DisplayChannelWrapper(Channel::new()));
    let interaction_channel = INTERACTION_EVENT_CHANNEL.get_or_init(|| InteractionChannelWrapper(Channel::new()));
    let battery_ready   = BATTERY_FUEL_READY.get_or_init(|| BatteryFuelReadySignal::new());

    let b =VirtualBatteryState::new_default();
    let v_nominal_mv = b.design_voltage_mv;

    // let observer = SYS_OBS.init(SystemObserver::new(
    //     Thresholds::new(),
    //     v_nominal_mv,
    //     display_channel
    // ));
    let battery_fuel = BATTERY_FUEL.init(BatteryDevice::new(BatteryServiceDeviceId(BATTERY_DEV_NUM)));

    SHARED.get_or_init(|| SHARED_CELL.init(Shared {
        // observer,
        battery_channel,
        charger_channel,
        thermal_channel,
        display_channel,
        interaction_channel,
        battery_ready,
        battery_fuel,
    }))
}
```

Note the references to `observer` are commented out for now... we'll attach those in a later step.

We'll continue the bootstrapping of our integration setup in the next step, where we will set up the components into our scaffolding.




