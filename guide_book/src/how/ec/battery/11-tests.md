# Unit Tests

In the previous exercises, we have built an implementation of a SmartBattery for our Mock Battery, and shown we can implement it into a service registry where it can be called upon by a service.

The next step is to test our implementation through a series of Unit Tests.
Unit Tests will insure the implementation produces the results we expect.  Early on, we had simply printed some values to the console to verify certain values.  This is not a good method of testing because the print action cannot be part of the final build.  Instead, we want to use a Unit Test harness that will allow us to inspect our otherwise silent build and report the values within it.

This will also allow us to continue to develop additional features of the battery as we simulate its behavior for charge over time.  This approach is commonly known as "Test Driven Development" (TDD) and is a strong pattern to adopt for any development scenario, perhaps even moreso for embedded device development.

## Types of Tests and where to put them
A __Unit Test__ typically is scoped to test only the capabilities of a single component or "unit" of code.
An __Integration Test__ is a test that either tests different implementations of a single unit structure, or else the integration of more than one component and the interactions between these components.

Code for Integration Tests are typically in a separate .rs file (often within a 'test' directory).  Unit Tests may also be separate, but it is also conventional for Unit Tests to be included in the same Rust code file as the component code itself.
In our Mock Battery case, we will put these first tests within our mock_battery.rs file.
This keeps our tests co-located with the implementation and avoids the need for additional test scaffolding.
Since we're implementing traits intended for broader reuse, but are only concerned with our one MockBattery implementation for now, embedding the tests here is both practical and instructive.

### Our first tests
So let's get started.  We're going to start with the mock battery itself. This keeps us focused on this basic level of functionality without adding additional complications of the abstraction layers introduced by wrapping it in a Device.  We'll return to this when we start writing directly for an embedded target and want to verify those levels. 

At the bottom of `mock_battery.rs` add this code:

```
#[cfg(test)]
mod tests {
    use super::*;
    use embedded_batteries::smart_battery::SmartBattery;

    #[test]
    fn test_voltage() {
        let mut battery = MockBattery;
        let voltage = battery.voltage().expect("Voltage should be readable");
        assert_eq!(voltage, 7500); // mV
    }

    #[test]
    fn test_state_of_charge() {
        let mut battery = MockBattery;
        let soc = battery.relative_state_of_charge().expect("SoC should be readable");
        assert_eq!(soc, 88); // percentage
    }

    #[test]
    fn test_temperature() {
        let mut battery = MockBattery;
        let temp = battery.temperature().expect("Temperature should be readable");
        assert_eq!(temp, 2950); // deci-Kelvin
    }

    #[test]
    fn test_manufacturer_name() {
        let mut battery = MockBattery;
        let mut buf = [0u8; 32];
        battery.manufacturer_name(&mut buf).expect("Should get manufacturer name");
        let name = core::str::from_utf8(&buf[..15]).expect("Valid UTF-8");
        assert_eq!(name, "MockBatteryCorp");
    }

    #[test]
    fn test_device_name() {
        let mut battery = MockBattery;
        let mut buf = [0u8; 32];
        battery.device_name(&mut buf).expect("Should get device name");
        let name = core::str::from_utf8(&buf[..8]).expect("Valid UTF-8");
        assert_eq!(name.trim_end_matches(char::from(0)), "MB-4200");
    }

    #[test]
    fn test_device_chemistry() {
        let mut battery = MockBattery;
        let mut buf = [0u8; 16];
        battery.device_chemistry(&mut buf).expect("Should get chemistry name");
        let name = core::str::from_utf8(&buf[..6]).expect("Valid UTF-8");
        assert_eq!(name.trim_end_matches(char::from(0)), "Li-Ion");
    }
}

```

### Running the test
When you are ready, type `cargo test` at the `battery_project` root.

You will see a lot of output because `cargo test` is going to test all the components of the workspace, including the ODP repository directories we've included.
There may be warning errors in some of these dependencies. But you will also see that all the tests pass, and looking more closely at the output you will see that there are indeed 6 tests reported for mock_battery that all pass.

> 📌 **Note about embedded dependencies and unit testing**
>
> While `cargo test -p mock_battery` would normally isolate this crate for testing,
> the embedded dependencies it brings in assume certain runtime features (like `critical-section` and `embassy_time`) that aren't defined in desktop builds.
>
> These assumptions cause linker errors unless we provide full backend implementations — something we’ll do later, when we shift to testing in a proper embedded target.
>
> For now, we can safely run our unit tests by invoking `cargo test` from the workspace root, and simply ignore unrelated test warnings from other crates.
> 
#### Fixing some of the warnings from the dependencies

It is not uncommon to encounter warnings in tests that are introduced from dependencies.  As one might appreciate, writing tests for a shared package that may be used in multiple different contexts can be challenging, and the focus on testing tends to center on the worthiness of the code in the package more than the viability of those tests being inherited by consuming packages.

You may be seeing warnings in the full test run we have done that originate from one or more of the dependent projects.

This is a common and recognizable problem and the Rust toolchain is aware of it and smart enough to assist.  

If there are warnings such as 'unused import', 'unused variable', incorrect field names (with suggestions), or notes about outdated or deprecated syntax, `cargo` can repair these for you.

So, for example, if you have a 'unused import' warning originating from the `embedded-services` repository in this workspace, you can try `cargo fix --lib -p embedded-services --tests --allow-no-vcs`
This will patch any offending test code that may have caused the previous warnings.  If you subsequently run `cargo test` the warnings should have disappeared.

### Continuing with TDD

Having gotten that cleared up, we are ready to continue to build out our tests and the corresponding behaviors for our mock battery to behave like a real battery might.


#### Defining the Time Trait `now`

To simulate charge or discharge over time in our mock battery, we need a way to track elapsed time. We'll use one actual time source here and another later when we are in-system on a target build.

To support this cleanly, we will define a TimeSource trait, 
and its implementation for our current test context.

```
pub trait TimeSource {
    fn now(&self) -> u64; // time in milliseconds
}

#[derive(Default)]
pub struct MockTime {
    time_ms: core::cell::Cell<u64>,
}

impl MockTime {
    pub fn new() -> Self {
        Self { time_ms: core::cell::Cell::new(0) }
    }

    pub fn advance(&self, delta_ms: u64) {
        let now = self.time_ms.get();
        self.time_ms.set(now + delta_ms);
    }
}

impl TimeSource for MockTime {
    fn now(&self) -> u64 {
        self.time_ms.get()
    }
}
```
This just defines a time that starts with an initial real time value, and advances the time by a given amount when we call `advance`. It could just as well start at 0 and be manually advanced for testing, but we'll go ahead and attach a real clock.

#### Adding a clock to the MockBattery
Let's give our MockBattery a TimeSource trait and a couple of reference values we will use later.  We'll use `std:rc::Rc` as a real-time clock reference for our testing for now.

📌 **Use of dynamic dispatch**
> Note: We're using dynamic dispatch here (`dyn TimeSource`) 
> for flexibility in swapping out implementations. In
> performance-sensitive code, a generic parameter might be
> preferable, but this approach keeps things simple and
> testable. 

```
use std::rc::Rc;

pub struct MockBattery {
    clock: Rc<dyn TimeSource>,
    #[allow(dead_code)]
    start_time: u64,
    #[allow(dead_code)]
    start_soc: u8,
}

impl MockBattery {
    // to create a battery with a self-contained internal clock
    pub fn new() -> Self {
        let clock = Rc::new(MockTime::new());
        let now = clock.now();
        Self {
            clock,
            start_time: now,
            start_soc: 100,
        }
    }
}
impl MockBattery {
    // to create a battery in which time time source is external
    pub fn with_clock(clock: Rc<dyn TimeSource>) -> Self {
        let now = clock.now();
        Self {
            clock,
            start_time: now,
            start_soc: 100,
        }
    }

    pub fn clock(&self) -> &Rc<dyn TimeSource> {
        &self.clock
    }
}

```
#### Update the battery instantiation
We now need to update every place in our first test code where we reference what was originally a static battery structure with a new instantiation.
Find all the lines like this:
```
let mut battery = MockBattery;
```
and replace with:
```
let mut battery = MockBattery::new();
```

And since we've changed MockBattery in this way we also need to fix the reference to it in `mock_battery_device.rs` or it won't compile.

In `mock_battery_device.rs` change
```
impl MockBatteryDevice {
    pub fn new(id: DeviceId) -> Self {
    Self {
            battery: MockBattery,
            device: Device::new(id)
        }
    }
```
to
```
impl MockBatteryDevice {
    pub fn new(id: DeviceId) -> Self {
    Self {
            battery:  MockBattery::new(),
            device: Device::new(id)
        }
    }
```

### Implementing dynamic battery behavior
Now that we have a time reference, we can support concepts like charge/discharge over time for our simulated battery.

#### Relative state of charge
The SmartBattery Specification, which we've implemented statically by providing values for the traits of our MockBattery implementation, defines a function `RelativeStateOfCharge` that we can use to determine the current battery capacity over time as it is discharged.

We have implemented this in our MockBattery currently, here:

```
    fn relative_state_of_charge(&mut self) -> Result<u8, Self::Error> {
        Ok(88)
    }
```
which will forever report our remaining capacity at 88%.

To make this dynamic and respect the other attributes implemented via our SmartBattery implmentation, we can change this function to the following:
```
fn relative_state_of_charge(&mut self) -> Result<u8, Self::Error> {
    let cap = match self.full_charge_capacity()? {
        CapacityModeValue::MilliAmpUnsigned(c) => c as u32,
        _ => return Ok(100),
    };

    let curr = self.average_current()? as i32;
    let discharge_ma = if curr <= 0 { 1 } else { curr };

    let elapsed_ms = self.clock.now().saturating_sub(self.start_time);
    let elapsed_mah = (elapsed_ms as i64 * discharge_ma as i64) / 3600_000;

    let remaining_mah = cap.saturating_sub(elapsed_mah.max(0) as u32);

    let percent = ((remaining_mah as f64 / cap as f64) * 100.0).round() as u8;
    Ok(percent.min(100))
}
```
This will give us a simulated discharge using a simple linear model.  A more sophisticated battery simulation may use a non-linear derivation or consider other factors (e.g. thermal effects) that we don't have available at the current time, but
our real goal is not to make the world's best battery simulation, but rather to learn how to connect _real_ batteries - no simulation needed - in the same way.  So this is fine.

#### Fixing the initial charge value
If we ran that test  now, it would fail because our first tests are still checking the original values we used when we constructed our SmartBattery implmentation.  So we need to change the test for this to expect 100 instead of 88, like it has been because we now are expecting a full charge at startup, per our dynamic function above.

So change `test_state_of_charge` to look like:
```
    #[test]
    fn test_state_of_charge() {
        let mut battery = MockBattery::new();
        let soc = battery.relative_state_of_charge().expect("SoC should be readable");
        assert_eq!(soc, 100); // fresh battery just instantiated
    }
```

#### Testing decrease over time
Now let's actually test for a decrease in charge over time with a new test function.

Add this test at teh bottom of the `#[cfg(test)]` block:

```
#[test]
fn test_dynamic_soc_decreases_over_time() {
    let clock = std::rc::Rc::new(MockTime::new());
    let mut battery = MockBattery::with_clock(clock.clone());

    // At time 0, should be near 100%
    let soc_initial = battery.relative_state_of_charge().unwrap();
    assert!(soc_initial >= 99, "Initial SoC should be close to 100, got {}", soc_initial);

    // Advance 1 hour (3600_000 ms)
    clock.advance(3600_000);

    // Now SoC should have decreased
    let soc_after_1h = battery.relative_state_of_charge().unwrap();
    assert!(soc_after_1h < soc_initial, "SoC should decrease after 1h");
    assert!(soc_after_1h <= 100, "SoC should be at most 100%");
}

```
As you can see, this test gets the initial value of our charge, which should be 100%, then uses our TimeSource to advance time one hour after  the initial charge of 100%, then tests 
As you can see, this test gets the initial value of our charge, which should be 100%, then uses our TimeSource to advance time one hour after and verifies that the charge is < 100%

For the next section, we need to stop working on our desktop build and move forward with an embedded target.







