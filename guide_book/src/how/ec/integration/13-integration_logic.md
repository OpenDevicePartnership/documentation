# Integration Logic

The `get_dynamic_data()` method is our tap point for integration logic.  However, for code organization if nothing else, we will be placing all the code for this into a new file `integration_logic.rs` and calling into it from the `get_dynamic_data()` interception point.

Create `integration_logic.rs` and give it this content to start for now:

```rust
use battery_service::controller::Controller;
use battery_service::device::DynamicBatteryMsgs;
use crate::controller_core::ControllerCore;
use mock_battery::mock_battery::MockBatteryError;


pub async fn integration_logic(core: &mut ControllerCore)  -> Result<DynamicBatteryMsgs, MockBatteryError> {
    let dd = core.battery.get_dynamic_data().await?;
    println!("integration_logic: got dynamic data: {:?}", dd);
    Ok(dd)
}
```

add this module to `main.rs`:

```rust
mod integration_logic;
``` 

Now, modify the `get_dynamic_data()` method in `controller_core.rs` to call into this new function:

```rust
    async fn get_dynamic_data(&mut self) -> Result<DynamicBatteryMsgs, MockBatteryError> {
        println!("ControllerCore: get_dynamic_data() called");
        crate::integration_logic::integration_logic(self).await
    }
``` 
And while we are in the area, let's comment out the `println!` statement for the `get_timeout()` trait method.  We know that the battery-service calls this frequently to get the timeout duration, but we don't need to see that in our output every time:
```rust
    fn get_timeout(&self) -> Duration {
        // println!("🥳 >>>>> get_timeout has been called!!! <<<<<<");
        self.battery.get_timeout()
    }
```

If we run the program now with `cargo run`, we should see output like this:
```
🚀 Interactive mode: integration project
setup_and_tap_starting
⚙️ Initializing embedded-services
⚙️ Spawning battery service task
⚙️ Spawning battery wrapper task
🧩 Registering battery device...
🧩 Registering charger device...
🧩 Registering sensor device...
🧩 Registering fan device...
🔌 Initializing battery fuel gauge service...
Setup and Tap calling ControllerCore::start...
In ControllerCore::start()
spawning controller_core_task
spawning start_charger_task
spawning charger_policy_event_task
init complete
🥺 Doing battery service startup -- DoInit followed by PollDynamicData
✅ Charger is ready.
🥳 >>>>> ping has been called!!! <<<<<<
🛠️  Charger initialized.
battery-service DoInit -> Ok(Ack)
🥳 >>>>> get_static_data has been called!!! <<<<<<
ControllerCore: get_dynamic_data() called
integration_logic: got dynamic data: DynamicBatteryMsgs { max_power_mw: 0, sus_power_mw: 0, full_charge_capacity_mwh: 4800, remaining_capacity_mwh: 4800, relative_soc_pct: 100, cycle_count: 0, voltage_mv: 4200, max_error_pct: 1, battery_status: 0, charging_voltage_mv: 0, charging_current_ma: 0, battery_temp_dk: 2982, current_ma: 0, average_current_ma: 0 }
ControllerCore: get_dynamic_data() called
integration_logic: got dynamic data: DynamicBatteryMsgs { max_power_mw: 0, sus_power_mw: 0, full_charge_capacity_mwh: 4800, remaining_capacity_mwh: 4800, relative_soc_pct: 100, cycle_count: 0, voltage_mv: 4200, max_error_pct: 1, battery_status: 0, charging_voltage_mv: 0, charging_current_ma: 0, battery_temp_dk: 2982, current_ma: 0, average_current_ma: 0 }
```
with the data dump from `get_dynamic_data()` repeated on each poll.

Before we start to get involved in the details of the integration logic, let's pivot to the display and interaction side of things.  We will need to have those pieces in place to be able to see the results of our integration logic as we develop it.
