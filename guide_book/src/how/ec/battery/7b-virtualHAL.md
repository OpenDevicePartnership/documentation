# A Virtual Battery

It bears repeating that the outcome of this exercise will be a _virtual_ battery, and not an attachment to real battery hardware.

We are going to construct a virtual battery simulator in this step, but this is a good time to note what we would be doing instead if we were working with real battery hardware at this point.

> ### Implementing a HAL layer
> In our virtual Mock Battery, we will not be attaching to any actual hardware.
> But if we were, this would be the place to do it.
>
> A brief overview of what these steps would be include:
> - Consulting the specifications of our hardware to explore its features
> - Determine which of these features would be necessary to fulfill each trait from the SBS specification we wish to implement
> - Define the traits that name these features or feature sequences.
> - Implement these traits in hardware (GPIO / MMIO, etc)
> - Use this to fulfill the SBS traits for the values required.
>
> For our mock battery, we will simply return coded values for the SBS traits directly.
>
> ------

## The Virtual Battery state machine

Instead of a HAL layer, we will construct a battery that operates entirely through software.
This will be a state machine with functions to compute values and simulate behavior over time that is consistent with its real-world counterpart.

This may not be the most sophisticated or comprehensive battery simulator one could construct, but it will be more than sufficient for our purposes.

Create a file named `virtual_battery.rs` and give it these initial contents:
```rust


use embedded_batteries_async::smart_battery::{
    BatteryModeFields, BatteryStatusFields, 
    SpecificationInfoFields, ManufactureDate,
    CapacityModeSignedValue, CapacityModeValue,
    ErrorCode
};

const STARTING_RSOC_PERCENT:u8 = 100;
const STARTING_ASOC_PERCENT:u8 = 100;
const STARTING_REMAINING_CAP_MAH:u16 = 4800;
const STARTING_FULL_CAP_MAH:u16 = 4800;
const STARTING_CHARGE_CURRENT_MA:u16 =  2000;
const STARTING_CHARGE_VOLTAGE_MV:u16 = 8400;
const STARTING_VOLTAGE_MV:u16 = 4200;
const STARTING_TEMPERATURE_DECIKELVINS:u16 = 2982; // 25 dec C.
const STARTING_DESIGN_CAP_MAH:u16 = 5000;
const STARTING_DESIGN_VOLTAGE_MV:u16 = 7800;


use crate::mock_battery::MockBatteryError;

/// Represents the internal, simulated state of a battery
#[derive(Debug, Clone)]
pub struct VirtualBatteryState {
    pub voltage_mv: u16,
    pub current_ma: i16,
    pub avg_current_ma: i16,
    pub temperature_dk: u16,
    pub relative_soc_percent: u8,
    pub absolute_soc_percent: u8,
    pub remaining_capacity_mah: u16,
    pub full_charge_capacity_mah: u16,
    pub runtime_to_empty_min: u16,
    pub avg_time_to_empty_min: u16,
    pub avg_time_to_full_min: u16,
    pub charging_current_ma: u16,
    pub charging_voltage_mv: u16,
    pub cycle_count: u16,
    pub design_capacity_mah: u16,
    pub design_voltage_mv: u16,
    pub battery_mode: BatteryModeFields,
    pub at_rate: CapacityModeSignedValue,
    pub remaining_capacity_alarm: CapacityModeValue,
    pub remaining_time_alarm_min: u16,
    pub at_rate_time_to_full: u16,
    pub at_rate_time_to_empty: u16,
    pub at_rate_ok: bool,
    pub max_error: u8,
    pub battery_status: BatteryStatusFields,
    pub specification_info: SpecificationInfoFields,
    pub serial_number: u16,
}

impl VirtualBatteryState {
    /// Create a fully charged battery with default parameters
    pub fn new_default() -> Self {
        let mut battery = Self {
            relative_soc_percent: STARTING_RSOC_PERCENT,
            absolute_soc_percent: STARTING_ASOC_PERCENT,
            remaining_capacity_mah: STARTING_REMAINING_CAP_MAH,
            full_charge_capacity_mah: STARTING_FULL_CAP_MAH,
            charging_current_ma: STARTING_CHARGE_CURRENT_MA,
            charging_voltage_mv: STARTING_CHARGE_VOLTAGE_MV,
            design_capacity_mah: STARTING_DESIGN_CAP_MAH,
            design_voltage_mv: STARTING_DESIGN_VOLTAGE_MV,
            voltage_mv: 0,
            temperature_dk: 0,
            at_rate_time_to_full: 0,
            at_rate_time_to_empty: 0,
            at_rate_ok: false,
            max_error: 1,
            battery_status: {
                let mut bs = BatteryStatusFields::new();
                bs.set_error_code(ErrorCode::Ok); 
                bs
            },
            specification_info: SpecificationInfoFields::from_bits(0x0011),
            serial_number: 0,
            current_ma: 0,
            avg_current_ma: 0,
            runtime_to_empty_min: 0,
            avg_time_to_empty_min: 0,
            avg_time_to_full_min: 0,
            cycle_count: 0,
            battery_mode: BatteryModeFields::default(),
            at_rate: CapacityModeSignedValue::MilliAmpSigned(0),
            remaining_capacity_alarm: CapacityModeValue::MilliAmpUnsigned(0),
            remaining_time_alarm_min: 0

        };
        battery.reset();
        battery
    }

    /// Advance the battery simulation by one tick (e.g., 1 second)
    pub fn tick(&mut self, multiplier:f32) {
        // 1. Update remaining capacity
        let delta_f = (self.current_ma as f32 / 3600.0) * multiplier; // allows external control over simulation pacing
        let delta = delta_f.round() as i32;
        let new_remaining = (self.remaining_capacity_mah as i32 + delta)
            .clamp(0, self.full_charge_capacity_mah as i32) as u16;

        // 2. Detect charge-to-discharge crossover for cycle tracking
        if self.current_ma < 0 && self.remaining_capacity_mah > new_remaining && new_remaining == 0 {
            self.cycle_count += 1;
        }

        self.remaining_capacity_mah = new_remaining;

        // 3. Recalculate voltage
        self.voltage_mv = self.estimate_voltage();

        // 4. Adjust average current toward current_ma
        self.avg_current_ma = ((self.avg_current_ma as i32 * 7 + self.current_ma as i32) / 8) as i16;

        // 5. Simulate temp change
        let temp = self.temperature_dk as i32 + self.estimate_temp_change() as i32;
        self.temperature_dk = temp.clamp(0, u16::MAX as i32) as u16;

        // 6. State of Charge updates
        self.relative_soc_percent = ((self.remaining_capacity_mah as f32 / self.full_charge_capacity_mah as f32) * 100.0).round() as u8;
        self.absolute_soc_percent = self.relative_soc_percent.saturating_sub(3); // Or another logic

    }


    /// Estimate voltage based on SoC
    fn estimate_voltage(&self) -> u16 {
        let soc = self.remaining_capacity_mah as f32 / self.full_charge_capacity_mah as f32;
        let min_v = 3000.0;
        let max_v = 4200.0;
        (min_v + (max_v - min_v) * soc) as u16
    }

    /// Simple model for temperature change under load (in deciKelvins)
    fn estimate_temp_change(&self) -> i8 {
        if self.current_ma.abs() > 1000 {
            1 // heating up
        } else if self.temperature_dk > 2982 { // 25 deg C = 2982 DeciKelvins
            -1 // cooling down toward idle
        } else {
            0 // stable
        }
    }

    pub fn time_to_empty_minutes(&self) -> u16 {
        if self.current_ma < 0 {
            ((self.remaining_capacity_mah as i32 * 60) / -self.current_ma as i32)
                .clamp(0, u16::MAX as i32) as u16
        } else {
            u16::MAX
        }
    }

    pub fn time_to_full_minutes(&self) -> u16 {
        if self.current_ma > 0 {
            (((self.full_charge_capacity_mah - self.remaining_capacity_mah) as i32 * 60) / self.current_ma as i32)
                .clamp(0, u16::MAX as i32) as u16
        } else {
            u16::MAX
        }
    }    

    /// Set the current draw (- discharge, + charge)
    pub fn set_current(&mut self, current_ma: i16) {
        self.current_ma = current_ma;
    }

    /// Reset to fully charged, idle
    pub fn reset(&mut self) {
        self.remaining_capacity_mah = self.full_charge_capacity_mah;
        self.voltage_mv = STARTING_VOLTAGE_MV;
        self.temperature_dk = STARTING_TEMPERATURE_DECIKELVINS;
        self.charging_voltage_mv = STARTING_CHARGE_VOLTAGE_MV;
        self.charging_current_ma = STARTING_CHARGE_CURRENT_MA;
        self.current_ma = 0;
        self.avg_current_ma = 0;
        self.cycle_count = 0;
        self.battery_mode = BatteryModeFields::default();
        self.at_rate = CapacityModeSignedValue::MilliAmpSigned(0);
        self.remaining_capacity_alarm = CapacityModeValue::MilliAmpUnsigned(0);
        self.remaining_time_alarm_min = 0;
    }

    pub fn manufacture_date(&mut self) -> Result<ManufactureDate, MockBatteryError> {
        let mut date = ManufactureDate::new();
        date.set_day(1);
        date.set_month(1);
        date.set_year(2025 - 1980); // must use offset from 1980   
        Ok(date)     
    }

    pub fn manufacturer_name(&mut self, buf: &mut [u8]) -> Result<(), MockBatteryError> {
        let name = b"MockBatteryCorp\0"; // Null-terminated string
        buf[..name.len()].copy_from_slice(name);
        Ok(())
    } 

    pub fn device_name(&mut self, buf: &mut [u8]) -> Result<(), MockBatteryError> {
        let name = b"MB-4200\0";
        buf[..name.len()].copy_from_slice(name);
        Ok(())
    }    

    pub fn device_chemistry(&mut self, buf: &mut [u8]) -> Result<(), MockBatteryError> {
        let name = b"LION\0";   // Null-terminated 5-byte string
        buf[..name.len()].copy_from_slice(name);
        Ok(())
    }
    
}

```

### Up

What we've done here is to define a virtual battery as a set of states. These coincide with the values we will need from the `MockBattery` to satisfy the `SmartBattery` traits. 

We initialize our virtual battery with some constant starting values, and include a reset function that sets the values back to
a fully charged, idle state.  We offer some helper functions to return some of the dynamic value computations and to relay
constant string values.

This virtual construction allows us to simulate stateful battery behavior without any actual hardware dependencies.

Of most interest, however, is perhaps the `tick()` function that controls the simulation.

Here, the caller passes in a `multiplier` value to control how fast the simulation runs (1x == 1 simulated second per tick).
From this delta, the effects of current draw or charge on the battery reserves and its temperature are computed and
the corresponding states are updated.

### Add to lib.rs
We need to make this `virtual_battery` module visible to the rest of the project, so add it to your `lib.rs` file as so:

```rust
pub mod mock_battery;
pub mod virtual_battery;
```

## Attaching to MockBattery

Now we are going to attach our virtual battery to our `MockBattery` construction so that it can implement the `SmartBattery` traits by calling upon our `VirtualBatteryState`.

Edit your `mock_battery.rs` file.  

At the top, add these imports:

```rust
extern crate alloc;
use crate::virtual_battery::VirtualBatteryState;
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::mutex::Mutex;
use alloc::sync::Arc;
```
This will give us access to our virtual battery construction and supply the necessary thread-safe wrappers we will need to access it.

We need to update our `MockBattery` to accommodate an inner `VirtualBatteryState` property.  
Replace the line that currently reads
```rust
pub struct MockBattery;
```
With this block of code instead:
```rust
pub struct MockBattery {
    pub state: Arc<Mutex<ThreadModeRawMutex, VirtualBatteryState>>,
}

impl MockBattery {
    pub fn new() -> Self {
        Self {
            state: Arc::new(Mutex::new(VirtualBatteryState::new_default())),
        }
    }
}

```
Now we can proceed to replace the current placeholder implementations of the `SmartBattery` traits.

To do this, we will be changing the function signature patterns from `async fn function_name(&mut self) -> Result<(), Self:Error>` to `fn function_name(&mut self) -> impl Future<Output = Result<(), Self::Error>>`

This is in fact a valid replacement that satisfies the trait requirement because although we are not implementing an async function, we are implementing one that returns a future, which amounts to the same thing.  But it is necessary to do here because we are capturing shared state behind a mutex, which introduces constraints that conflict with the way `async fn` in trait implementations is normally handled. By returning a `Future` explicitly and using an `async move` block, we gain the flexibility needed to safely lock and use that shared state within the method, while still satisfying the trait.

> **Why can't we just use `async fn`?**
>
> While the `SmartBattery` trait defines its methods using `async fn`, and our earlier implementation used that form successfully, it no longer works once we introduce shared mutable state behind a `Mutex`. Here's why:
>
> - `async fn` in a trait impl desugars to a fixed, compiler-generated future type.
> - This future type must be safely transferrable and nameable in the trait system.
> - When the body of the `async fn` captures a value like `self.state.lock().await`, it may no longer satisfy required bounds like `Send`.
> - This is especially true when using `embassy_sync::Mutex`, which is designed for embedded systems and is **not `Send`**.
> - As a result, the compiler refuses the `async fn` because it cannot produce a compatible future that satisfies the trait's expectations.
>
> ✅ The solution is to return a `Future` explicitly:
>
> - This allows us to construct the future manually using an `async move` block.
> - We can safely capture non-`Send` values inside this block (such as a mutex guard).
> - It also avoids lifetime or type inference issues that might arise from compiler-generated future types in trait contexts.
>
> This pattern is not only more flexible but necessary whenever your async code interacts with embedded, single-threaded, or non-`Send` systems—like those commonly used with `no_std` or simulated devices.


With this in mind, we can then implement calls into our `VirtualBatteryState` by following a pattern such as the one exhibited here:
```rust
    fn voltage(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.voltage_mv)
        }            
    }
```
Where we obtain access to our `VirtualBatteryState` property and then use `async move` to obtain a mutex lock for thread safety, and then return the value from the locked state as a Result.    


### A completed integration 

When we repeat that pattern of integration for each of the `SmartBattery` traits, the end result looks like this:

```rust
impl SmartBattery for MockBattery {
    fn remaining_capacity_alarm(&mut self) -> impl Future<Output = Result<CapacityModeValue, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.remaining_capacity_alarm)
        }
    }

    fn set_remaining_capacity_alarm(&mut self, val: CapacityModeValue) -> impl Future<Output = Result<(), Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = &mut state.lock().await;
            lock.remaining_capacity_alarm = val;
            Ok(())
        }
    }

    fn remaining_time_alarm(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.remaining_time_alarm_min)
        }
    }

    fn set_remaining_time_alarm(&mut self, val: u16) -> impl Future<Output = Result<(), Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = &mut state.lock().await;
            lock.remaining_time_alarm_min = val;
            Ok(())
        }
    }

    fn battery_mode(&mut self) -> impl Future<Output = Result<BatteryModeFields, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.battery_mode)
        }
    }

    fn set_battery_mode(&mut self, val: BatteryModeFields) -> impl Future<Output = Result<(), Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = &mut state.lock().await;
            lock.battery_mode = val;
            Ok(())
        }
    }

    fn at_rate(&mut self) -> impl Future<Output = Result<CapacityModeSignedValue, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.at_rate)
        }
    }

    fn set_at_rate(&mut self, val: CapacityModeSignedValue) -> impl Future<Output = Result<(), Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = &mut state.lock().await;
            lock.at_rate = val;
            Ok(())
        }
    }

    fn at_rate_time_to_full(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.at_rate_time_to_full)
        }
    }

    fn at_rate_time_to_empty(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.at_rate_time_to_empty)
        }
    }

    fn at_rate_ok(&mut self) -> impl Future<Output = Result<bool, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.at_rate_ok)
        }
    }

    fn temperature(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.temperature_dk)
        }
    }

    fn voltage(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.voltage_mv)
        }            
    }

    fn current(&mut self) -> impl Future<Output = Result<i16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.current_ma)
        }
    }

    fn average_current(&mut self) -> impl Future<Output = Result<i16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.avg_current_ma)
        }
    }

    fn max_error(&mut self) -> impl Future<Output = Result<u8, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.max_error)
        }
    }

    fn relative_state_of_charge(&mut self) -> impl Future<Output = Result<u8, MockBatteryError>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.relative_soc_percent)
        }
    }

    fn absolute_state_of_charge(&mut self) -> impl Future<Output = Result<u8, MockBatteryError>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.absolute_soc_percent)
        }
    }

    fn remaining_capacity(&mut self) -> impl Future<Output = Result<CapacityModeValue, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(CapacityModeValue::MilliAmpUnsigned(lock.remaining_capacity_mah))
        }
    }

    fn full_charge_capacity(&mut self) -> impl Future<Output = Result<CapacityModeValue, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(CapacityModeValue::MilliAmpUnsigned(lock.full_charge_capacity_mah))
        }
    }

    fn run_time_to_empty(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.time_to_empty_minutes())
        }
    }

    fn average_time_to_empty(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.avg_time_to_empty_min)
        }
    }

    fn average_time_to_full(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.avg_time_to_full_min)
        }
    }

    fn charging_current(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.charging_current_ma)
        }
    }

    fn charging_voltage(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.charging_voltage_mv)
        }
    }

    fn battery_status(&mut self) -> impl Future<Output = Result<BatteryStatusFields, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.battery_status)
        }
    }

    fn cycle_count(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.cycle_count)
        }
    }

    fn design_capacity(&mut self) -> impl Future<Output = Result<CapacityModeValue, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(CapacityModeValue::MilliAmpUnsigned(lock.design_capacity_mah))
        }
    }

    fn design_voltage(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.design_voltage_mv)
        }
    }

    fn specification_info(&mut self) -> impl Future<Output = Result<SpecificationInfoFields, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.specification_info)
        }
    }

    fn manufacture_date(&mut self) -> impl Future<Output = Result<ManufactureDate, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = &mut state.lock().await;
            lock.manufacture_date()
        }
    }

    fn serial_number(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = state.lock().await;
            Ok(lock.serial_number)
        }
    }

    fn manufacturer_name(&mut self, buf: &mut [u8]) -> impl Future<Output = Result<(), Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = &mut state.lock().await;
            lock.manufacturer_name(buf)
        }
    }

    fn device_name(&mut self, buf: &mut [u8]) -> impl Future<Output = Result<(), Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = &mut state.lock().await;
            lock.device_name(buf)
        }
    }

    fn device_chemistry(&mut self, buf: &mut [u8]) -> impl Future<Output = Result<(), Self::Error>> {
        let state = self.state.clone();
        async move {
            let lock = &mut state.lock().await;
            lock.device_chemistry(buf)
        }
    }
}
```

### Cargo.toml additions
We also need to update our `Cargo.toml` files.  In `mock_battery/Cargo.toml`, add the following to your `[dependencies]` section:

```toml
embassy-sync = { workspace = true, features=["std"] }
critical-section = {version = "1.0", features = ["std"] }
async-trait = "0.1"
```

and in your top-level `Cargo.toml` (`battery_project/Cargo.toml`), add this:
```toml
[workspace.dependencies]
embassy-sync = "0.7.0"
```

## Now to expose this to the service

We have defined the battery traits and their behaviors in `virtual_battery.rs` and implemented these as the `SmartBattery` traits exposed by `mock_battery.rs`

Our `virtual_battery.rs` serves as a software-only replacement for what would be a HAL implementation, with the difference being that state values would be drawn from the actual hardware circuitry, per manufacturer design (i.e. GPIO or MMIO), and helper functions to align these to SBS compliant concepts would be created instead, and of course, there would be no "simulation" function needed in a real-world design.

But before any of what we've created is useful, it needs to be exposed to the service layer.  In the next step, we'll do a simple test that shows we can expose these values, and then we'll start the processes to implement the service layer that conveys these up the chain in response to service messages.


