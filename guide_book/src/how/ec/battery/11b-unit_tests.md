# Mock Battery Unit Tests

Unit Tests are customarily included within the file that contains the code for the unit being tested.  Typically, there is
one test for each feature of the unit under test.

In our modified async-helper test structure, there will be only a single `#[test]` entry point that will spawn a series of asynchronous tasks that will test the traits of our MockBattery at initial state.

Later we will explore _integration tests_ to test runtime behaviors of the battery, and those will be in a separate test file.

## Our first tests

Let's get started, then.  Edit your `mock_battery.rs` file and add this code to the end of it:

```rust
//------------------------
#[cfg(test)]
use crate::test_helper::join_signals;
#[allow(unused_imports)]
use embassy_executor::Executor;
#[allow(unused_imports)]
use embassy_sync::signal::Signal;
#[allow(unused_imports)]
use static_cell::StaticCell;


#[test]
fn test_initial_traits() {
    static EXECUTOR: StaticCell<Executor> = StaticCell::new();
    static VOLT_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static CUR_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();

    let executor = EXECUTOR.init(Executor::new());
    let voltage_done: &'static Signal<RawMutex, ()> = VOLT_DONE.init(Signal::new());
    let current_done: &'static Signal<RawMutex, ()> = CUR_DONE.init(Signal::new());

    executor.run(|spawner| {        
        spawner.must_spawn(voltage_test_task(&voltage_done));
        spawner.must_spawn(current_test_task(&current_done));
        join_signals(&spawner, [voltage_done, current_done]);
    });
}

#[embassy_executor::task]
async fn voltage_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let voltage = battery.voltage().await.unwrap();
    assert_eq!(voltage, 4200);
    done.signal(())
}

#[embassy_executor::task]
async fn current_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let current = battery.average_current().await.unwrap();
    assert_eq!(current, 0);
    done.signal(())
}
```

To explain this:

We start the test section by requiring the necessary imports, including one from our `test_helper`.  We use `#[cfg(test)]` and `#[allow(unused_imports)]` to avoid warnings during compilation between test/non-test modes.

We have defined two separate trait tests to verify that the starting values of our MockBattery are at their expected values, one for voltage, and one for current.   These are in the form of `#[embassy_executor::task]` functions that are executed by `spawn` statements from the test code.  This is essentially the same as what we do in our `main()` execution code, but performed as a `#[test]` block instead.

The `#[test]` block itself performs the necessary setup for the test tasks it will call upon. It instantiates the `Executor` 
and the "DONE" signals we need for each of the test tasks we will spawn.  It then proceeds to spawn each of these tasks and
calls upon our helper `join_signals` to wait for all the tests to complete and then exit the test.

Other (synchronous) `#[test]` blocks could be included if there was more to test in this module than just our asynchronous traits.  We could also put each trait test in its own `#[test]` setup block that spawns only a single task. But this would be unnecessarily verbose and use more overhead than necessary.  

### Run the tests

The command `cargo test -p mock_battery` should show you that 1 test sucessfully ran.  It will not report an 'ok' because the test was forced to exit due to the nature of the test helper before the `#[test]` process returned.

### Forcing a failure

If a test fails, it will be reported.  Temporarily change one of the test assertions to see this.  For example, change the assertion in `current_test_task` to read
```rust
assert_eq!(current, 1);
```
The battery current at initial state should be zero, so this test will fail.

`cargo test -p mock_battery`:

You should see output similar to this:
```
running 1 test
test mock_battery::test_spawns ... FAILED

failures:

---- mock_battery::test_spawns stdout ----

thread 'mock_battery::test_spawns' panicked at mock_battery\src\mock_battery.rs:371:5:
assertion `left == right` failed
  left: 0
 right: 1
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace


failures:
    mock_battery::test_spawns

test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s  
```

### Testing the remaining traits

With the pattern established, we can easily add tests for the remaining traits initial state values
1. Create the test task as an `#[embassy-executor::task]`
2. Add a signal declaration for the 'done' signal
3. Pass this signal to the task when spawning the task and add it to the array passed to join_signals.

Our completed traits test might look something like this:

```rust
//------------------------
#[cfg(test)]
use crate::test_helper::join_signals;
#[allow(unused_imports)]
use embassy_executor::Executor;
#[allow(unused_imports)]
use embassy_sync::signal::Signal;
#[allow(unused_imports)]
use static_cell::StaticCell;


#[test]
fn test_initial_traits() {
    static EXECUTOR: StaticCell<Executor> = StaticCell::new();

    static RCA_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static RTA_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static BMODE_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static ATRATE_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static ATRATE_TTF_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static ATRATE_TTE_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static ATRATE_OK_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static TEMP_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static VOLT_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static CUR_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static AVG_CUR_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static MAXERR_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static RSOC_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static ASOC_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static REM_CAP_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static FCC_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static RTE_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static ATE_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static ATF_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static CHG_CUR_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static CHG_VOLT_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static BAT_STAT_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static CYCLE_COUNT_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static DES_CAP_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static DES_VOLT_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static SPEC_INFO_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static MAN_DATE_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static SER_NUM_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static MAN_NAME_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static DEV_NAME_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static DEV_CHEM_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();


    


    let executor = EXECUTOR.init(Executor::new());

    let rem_cap_alarm_done= RCA_DONE.init(Signal::new());
    let rem_time_alarm_done = RTA_DONE.init(Signal::new());
    let bat_mode_done = BMODE_DONE.init(Signal::new());
    let at_rate_done = ATRATE_DONE.init(Signal::new());
    let at_rate_ttf_done = ATRATE_TTF_DONE.init(Signal::new());
    let at_rate_tte_done = ATRATE_TTE_DONE.init(Signal::new());
    let at_rate_ok_done = ATRATE_OK_DONE.init(Signal::new());
    let temperature_done= TEMP_DONE.init(Signal::new());
    let voltage_done = VOLT_DONE.init(Signal::new());
    let current_done = CUR_DONE.init(Signal::new());
    let avg_cur_done = AVG_CUR_DONE.init(Signal::new());
    let max_err_done = MAXERR_DONE.init(Signal::new());
    let rsoc_done = RSOC_DONE.init(Signal::new());
    let asoc_done = ASOC_DONE.init(Signal::new());
    let rem_cap_done = REM_CAP_DONE.init(Signal::new());
    let full_chg_cap_done = FCC_DONE.init(Signal::new());
    let rte_done = RTE_DONE.init(Signal::new());
    let ate_done = ATE_DONE.init(Signal::new());
    let atf_done = ATF_DONE.init(Signal::new());
    let chg_cur_done = CHG_CUR_DONE.init(Signal::new());
    let chg_volt_done = CHG_VOLT_DONE.init(Signal::new());
    let bat_stat_done = BAT_STAT_DONE.init(Signal::new());
    let cycle_count_done = CYCLE_COUNT_DONE.init(Signal::new());
    let des_cap_done = DES_CAP_DONE.init(Signal::new());
    let des_volt_done = DES_VOLT_DONE.init(Signal::new());
    let spec_info_done = SPEC_INFO_DONE.init(Signal::new());
    let man_date_done = MAN_DATE_DONE.init(Signal::new());
    let ser_num_done = SER_NUM_DONE.init(Signal::new());
    let man_name_done = MAN_NAME_DONE.init(Signal::new());
    let dev_name_done = DEV_NAME_DONE.init(Signal::new());
    let dev_chem_done = DEV_CHEM_DONE.init(Signal::new());


    executor.run(|spawner| {        
        spawner.must_spawn(rem_cap_alarm_test_task(rem_cap_alarm_done));
        spawner.must_spawn(rem_time_alarm_test_task(rem_time_alarm_done));
        spawner.must_spawn(bat_mode_test_task(bat_mode_done));
        spawner.must_spawn(at_rate_test_task(at_rate_done));
        spawner.must_spawn(at_rate_ttf_test_task(at_rate_ttf_done));
        spawner.must_spawn(at_rate_tte_test_task(at_rate_tte_done));
        spawner.must_spawn(at_rate_ok_test_task(at_rate_ok_done));
        spawner.must_spawn(temperature_test_task(temperature_done));
        spawner.must_spawn(voltage_test_task(voltage_done));
        spawner.must_spawn(current_test_task(current_done));
        spawner.must_spawn(avg_cur_test_task(avg_cur_done));
        spawner.must_spawn(max_err_test_task(max_err_done));
        spawner.must_spawn(rsoc_test_task(rsoc_done));
        spawner.must_spawn(asoc_test_task(asoc_done));
        spawner.must_spawn(rem_cap_test_task(rem_cap_done));
        spawner.must_spawn(full_chg_cap_test_task(full_chg_cap_done));
        spawner.must_spawn(rte_test_task(rte_done));
        spawner.must_spawn(ate_test_task(ate_done));
        spawner.must_spawn(atf_test_task(atf_done));
        spawner.must_spawn(chg_cur_test_task(chg_cur_done));
        spawner.must_spawn(chg_volt_test_task(chg_volt_done));
        spawner.must_spawn(bat_stat_test_task(bat_stat_done));
        spawner.must_spawn(cycle_count_test_task(cycle_count_done));
        spawner.must_spawn(des_cap_test_task(des_cap_done));
        spawner.must_spawn(des_volt_test_task(des_volt_done));
        spawner.must_spawn(spec_info_test_task(spec_info_done));
        spawner.must_spawn(man_date_test_task(man_date_done));
        spawner.must_spawn(ser_num_test_task(ser_num_done));
        spawner.must_spawn(man_name_test_task(man_name_done));
        spawner.must_spawn(dev_name_test_task(dev_name_done));
        spawner.must_spawn(dev_chem_test_task(dev_chem_done));

        join_signals(&spawner, [
            rem_cap_alarm_done,
            rem_time_alarm_done,
            bat_mode_done,
            at_rate_done,
            at_rate_ttf_done,
            at_rate_tte_done,
            temperature_done,
            voltage_done, 
            current_done,
            avg_cur_done,
            max_err_done,
            rsoc_done,
            asoc_done,
            rem_cap_done,
            full_chg_cap_done,
            rte_done,
            ate_done,
            atf_done,
            chg_cur_done,
            chg_volt_done,
            bat_stat_done,
            cycle_count_done,
            des_cap_done,
            des_volt_done,
            spec_info_done,
            man_date_done,
            ser_num_done,
            man_name_done,
            dev_name_done,
            dev_chem_done
        ]);
    });
}

#[embassy_executor::task]
async fn rem_cap_alarm_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.remaining_capacity_alarm().await.unwrap();
    assert_eq!(value, CapacityModeValue::MilliAmpUnsigned(0));
    done.signal(())
}
#[embassy_executor::task]
async fn rem_time_alarm_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.remaining_time_alarm().await.unwrap();
    assert_eq!(value, 0);
    done.signal(())
}
#[embassy_executor::task]
async fn bat_mode_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let mode = battery.battery_mode().await.unwrap();
    assert_eq!(mode.capacity_mode(), false);
    done.signal(())
}
#[embassy_executor::task]
async fn at_rate_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.at_rate().await.unwrap();
    assert_eq!(value, CapacityModeSignedValue::MilliAmpSigned(0));
    done.signal(())
}
#[embassy_executor::task]
async fn at_rate_ttf_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.at_rate_time_to_full().await.unwrap();
    assert_eq!(value, 0);
    done.signal(())
}
#[embassy_executor::task]
async fn at_rate_tte_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.at_rate_time_to_empty().await.unwrap();
    assert_eq!(value, 0);
    done.signal(())
}
#[embassy_executor::task]
async fn at_rate_ok_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.at_rate_ok().await.unwrap();
    assert_eq!(value, false);
    done.signal(())
}
#[embassy_executor::task]
async fn temperature_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.temperature().await.unwrap();
    assert_eq!(value, 2982);
    done.signal(())
}
#[embassy_executor::task]
async fn voltage_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let voltage = battery.voltage().await.unwrap();
    assert_eq!(voltage, 4200);
    done.signal(())
}
#[embassy_executor::task]
async fn current_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let current = battery.current().await.unwrap();
    assert_eq!(current, 0);
    done.signal(())
}
#[embassy_executor::task]
async fn avg_cur_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.average_current().await.unwrap();
    assert_eq!(value, 0);
    done.signal(())
}
#[embassy_executor::task]
async fn max_err_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.max_error().await.unwrap();
    assert_eq!(value, 1);
    done.signal(())
}
#[embassy_executor::task]
async fn rsoc_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.relative_state_of_charge().await.unwrap();
    assert_eq!(value, 100);
    done.signal(())
}
#[embassy_executor::task]
async fn asoc_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.absolute_state_of_charge().await.unwrap();
    assert_eq!(value, 100);
    done.signal(())
}
#[embassy_executor::task]
async fn rem_cap_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.remaining_capacity().await.unwrap();
    assert_eq!(value, CapacityModeValue::MilliAmpUnsigned(4800));
    done.signal(())
}
#[embassy_executor::task]
async fn full_chg_cap_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.full_charge_capacity().await.unwrap();
    assert_eq!(value, CapacityModeValue::MilliAmpUnsigned(4800));
    done.signal(())
}
#[embassy_executor::task]
async fn rte_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.run_time_to_empty().await.unwrap();
    assert_eq!(value, 0xFFFF); 
    done.signal(())
}
#[embassy_executor::task]
async fn ate_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.average_time_to_empty().await.unwrap();
    assert_eq!(value, 0);
    done.signal(())
}
#[embassy_executor::task]
async fn atf_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.average_time_to_full().await.unwrap();
    assert_eq!(value, 0);
    done.signal(())
}
#[embassy_executor::task]
async fn chg_cur_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.charging_current().await.unwrap();
    assert_eq!(value, 2000);
    done.signal(())
}
#[embassy_executor::task]
async fn chg_volt_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.charging_voltage().await.unwrap();
    assert_eq!(value, 8400);
    done.signal(())
}
#[embassy_executor::task]
async fn bat_stat_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.battery_status().await.unwrap();
    assert_eq!(value, BatteryStatusFields::default());
    done.signal(())
}
#[embassy_executor::task]
async fn cycle_count_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.cycle_count().await.unwrap();
    assert_eq!(value, 0);
    done.signal(())
}
#[embassy_executor::task]
async fn des_cap_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.design_capacity().await.unwrap();
    assert_eq!(value, CapacityModeValue::MilliAmpUnsigned(5000));
    done.signal(())
}
#[embassy_executor::task]
async fn des_volt_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.design_voltage().await.unwrap();
    assert_eq!(value, 7800);
    done.signal(())
}
#[embassy_executor::task]
async fn spec_info_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let spec = battery.specification_info().await.unwrap();
    let summary = format!("{:?}", spec);
    assert!(summary.contains("version"));
    done.signal(())
}
#[embassy_executor::task]
async fn man_date_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let date = battery.manufacture_date().await.unwrap();
    assert_eq!(date.day(), 1);
    assert_eq!(date.month(), 1);
    assert_eq!(date.year() + 1980, 2025);
    done.signal(())
}
#[embassy_executor::task]
async fn ser_num_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let value = battery.serial_number().await.unwrap();
    assert_eq!(value, 0x0102);
    done.signal(())
}
#[embassy_executor::task]
async fn man_name_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let mut name = [0u8; 21];
    battery.manufacturer_name(&mut name).await.unwrap();
    assert_eq!(&name[..15], b"MockBatteryCorp");
    done.signal(())
}
#[embassy_executor::task]
async fn dev_name_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let mut name = [0u8; 21];
    battery.device_name(&mut name).await.unwrap();
    assert_eq!(&name[..7], b"MB-4200");
    done.signal(())
}
#[embassy_executor::task]
async fn dev_chem_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let mut chem = [0u8; 5];
    battery.device_chemistry(&mut chem).await.unwrap();
    assert_eq!(&chem[..4], b"LION");
    done.signal(())
}
```

### Testing setter behavior

A couple of methods of `MockBattery` concern setters that alter a value. Since these are not part of the initial state,
let's create another test block for these tests.  Put this below the other tests at the bottom of `mock_battery.rs`:

```rust
#[test]
fn test_setters() {
    static EXECUTOR: StaticCell<Executor> = StaticCell::new();
    let executor = EXECUTOR.init(Executor::new());

    static ALARM_SET_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    let alarm_set_done = ALARM_SET_DONE.init(Signal::new());

    executor.run(|spawner| {        
        spawner.must_spawn(alarm_set_test_task(alarm_set_done));
        join_signals(&spawner, [alarm_set_done]);
    });
}

#[embassy_executor::task]
async fn alarm_set_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();

    // remaining capacity alarm
    let old_cap = battery.remaining_capacity_alarm().await.unwrap();
    let new_cap = CapacityModeValue::CentiWattUnsigned(1234);
    assert_ne!(old_cap, new_cap);
    battery.set_remaining_capacity_alarm(new_cap).await.unwrap();
    let test_cap = battery.remaining_capacity_alarm().await.unwrap();
    assert_eq!(test_cap, new_cap);
    battery.set_remaining_capacity_alarm(old_cap).await.unwrap();

    // remaining time alarm
    let old_time = battery.remaining_time_alarm().await.unwrap();
    let new_time = 1234;
    assert_ne!(old_time, new_time);
    battery.set_remaining_time_alarm(new_time).await.unwrap();
    let test_time = battery.remaining_time_alarm().await.unwrap();
    assert_eq!(test_time, new_time);
    battery.set_remaining_time_alarm(old_time).await.unwrap();

    done.signal(())
}

```
These will verify that we can change the values for the remaining capacity and remaining time alarms.

### Testing a feature that isn't implemented

The `SmartBattery` Specification (SBS) supports the concept of _Battery Mode_.  The `battery_mode()` trait reports a set of bit field flags that tell which unit type various trait values should be represented as. For example, the capacity mode controls whether capacity is reported as MilliAmps or CentiWatts.  

We have not supported this in our `VirtualBatteryState` implementation. 

We can create another test task to test for this, though, and add it to our `test_setters` test.

```rust
#[embassy_executor::task]
async fn mode_set_test_task(done:  &'static Signal<RawMutex, ()>) {
    let mut battery = MockBattery::new();
    let old_mode = battery.battery_mode().await.unwrap();
    let new_mode = BatteryModeFields::new();
    BatteryModeFields::with_capacity_mode(new_mode, !old_mode.capacity_mode());
    battery.set_battery_mode(new_mode).await.unwrap();
    let test_mode = battery.battery_mode().await.unwrap();
    assert_eq!(test_mode.capacity_mode(), new_mode.capacity_mode());
    // now check a capacitymode value
    let expected_mode_value = CapacityModeValue::CentiWattUnsigned(2016);
    let value = battery.remaining_capacity().await.unwrap();
    assert_eq!(value, expected_mode_value);
    done.signal(())
}
```

and add the signal information in the test block for this new task.  Update the `test_setters` test block to this:

```rust
#[test]
fn test_setters() {
    static EXECUTOR: StaticCell<Executor> = StaticCell::new();
    let executor = EXECUTOR.init(Executor::new());

    static ALARM_SET_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    static MODE_SET_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();
    let alarm_set_done = ALARM_SET_DONE.init(Signal::new());
    let mode_set_done = MODE_SET_DONE.init(Signal::new());

    executor.run(|spawner| {        
        spawner.must_spawn(alarm_set_test_task(alarm_set_done));
        spawner.must_spawn(mode_set_test_task(mode_set_done));
        join_signals(&spawner, [alarm_set_done, mode_set_done]);
    });
}
```

when you run the tests, you will get an error:

```
---- mock_battery::test_setters stdout ----

thread 'mock_battery::test_setters' panicked at mock_battery\src\mock_battery.rs:762:5:
assertion `left == right` failed
  left: MilliAmpUnsigned(4800)
 right: CentiWattUnsigned(2016)


failures:
    mock_battery::test_initial_traits
    mock_battery::test_setters

test result: FAILED. 0 passed; 2 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

showing that the remaining capacity continued to be return in MilliAmps despite the mode being set for it to be returned
in CentiWatts.

We could fix the behavior in `virtual_battery.rs` to track and honor the mode setting and return values accordingly, and this will satisfy the test.  But our Mock Battery doesn't really need that feature.  You can remove this test (or just comment out that last assertion) if you like.

#### Test Driven Development

But this also demonstrates a proven development model.  _Test Driven Development (TDD)_ is a process by which the tests come first - written according to the specification of the API and applied to an implementation that is incomplete, and then 
the implementation is updated until all the tests pass.  This insures that software units are built to specification from the start.

You should never adjust a test to make it pass.  You should only fix the implementation. You should only modify test code if it is found to improperly enforce the specification.
