# Updating the Controller construction
Continuing our revisions to eliminate the unnecessary use of `duplicate_static_mut!` and adhere to a more canonical pattern that respects single ownership rules, we need to update the constructor for our component Controllers.
We also want to remove the unnecessary use of Generics in the design of these controllers.  We are only creating one variant of controller, there is no need to specify in a generic component in these cases, and generics are not only awkward to work with, they come with a certain amount of additional overhead.  This would be fine if we were actually taking advantage of different variant implementations, but since we are not, let's eliminate this now and simplify our design as long as we are making changes anyway.

## Updating the `MockChargerController` Constructor 
The `MockChargerController` currently takes both a `MockCharger` and a `MockChargerDevice` parameter.  The Controller doesn't actually use the `Device` context -- The `Device` is used to register the component with the service separately, but the component passed to the Controller must be the same as the one registered.  

For the `MockBatteryController`, we got around this by not passing the `MockBatteryDevice`, since it isn't used.  For the thermal components, `MockSensorController` and `MockFanController` are passed only the component `Device` instance and the component reference is extracted from here.

This latter approach is a preferable pattern because it ensures that the same component instance used for registration is also the one provided to the controller.  

We use the `get_internals()` method to return both the component and the `Device` instances instead of simply `inner_charger` because splitting the reference avoids inherent internal borrows on the same mutable 'self' reference.

We'll be updating many of our previous controllers, as well as `MockChargerDevice` to make things consistent and to ensure are using the right types and traits required for the ODP service registrations.

>📌 Why does `get_internals()` work where inner_charger() fails?
>
> This boils down to how the borrow checker sees the lifetime of the borrows.
>
> `inner_charger()` returns only `&mut MockCharger`,but the MockChargerDevice itself is still alive in the same scope. If you then also try to hand out `&mut Device` later, Rust sees that as two overlapping mutable borrows of the same struct, which is illegal.
>
> `get_internals()` instead performs both borrows inside the same method call and returns them as a tuple.
>
> This is a pattern the compiler can prove safe: it knows exactly which two disjoint fields are being borrowed at once, and it enforces that they don’t overlap.
>
> This is why controllers like our `MockSensorController`, `MockFanController`, and now `MockChargerController` can be cleanly instantiated with `get_internals()`. The `MockBatteryController` happens not to need this because it never touches the `Device` half of `MockBatteryDevice` — it only needs the component itself.

### The other Controllers
In our `MockSensorController` and `MockFanController` definitions, we did not make our `Device` or component members accessible, so we will change those now to do that and make them public.
It also turns out that we need a few changes to the implemented traits for these controllers that are necessary to make these eligible for registering for the ODP thermal services.  Plus, we will add a couple of new helper accessor functions to simplify our usage later.

Update `thermal_project/mock_thermal/src/mock_sensor_controller.rs` with this new version:
```rust

use crate::mock_sensor::{MockSensor, MockSensorError};
use crate::mock_sensor_device::MockSensorDevice;
use embedded_services::power::policy::device::Device;

use embedded_sensors_hal_async::temperature::{
    DegreesCelsius, TemperatureSensor, TemperatureThresholdSet
};
use ec_common::events::ThresholdEvent;
use embedded_sensors_hal_async::{sensor as sens, temperature as temp};
use thermal_service as ts;


pub struct MockSensorController {
    pub sensor: &'static mut MockSensor,
    pub device: &'static mut Device
}

///
/// Temperature Sensor Controller
/// 
impl MockSensorController {
    pub fn new(device: &'static mut MockSensorDevice) -> Self {
        let (sensor, device) = device.get_internals();
        Self {
            sensor,
            device
        }
    }

    // Check if temperature has exceeded the high/low thresholds and 
    // issue an event if so.  Protect against hysteresis.
    const HYST: f32 = 0.5;
    pub fn eval_thresholds(&mut self, t:f32, lo:f32, hi:f32,
        hi_latched: &mut bool, lo_latched: &mut bool) -> ThresholdEvent {

        // trip rules: >= hi and <= lo (choose your exact policy)
        if t >= hi && !*hi_latched {
            *hi_latched = true;
            *lo_latched = false;
            return ThresholdEvent::OverHigh;
        }
        if t <= lo && !*lo_latched {
            *lo_latched = true;
            *hi_latched = false;
            return ThresholdEvent::UnderLow;
        }
        // clear latches only after re-entering band with hysteresis
        if t < hi - Self::HYST { *hi_latched = false; }
        if t > lo + Self::HYST { *lo_latched = false; }
        ThresholdEvent::None            
    }

    pub fn set_sim_temp(&mut self, t: f32) { self.sensor.set_temperature(t); }
    pub fn current_temp(&self) -> f32 { self.sensor.get_temperature() }

}

impl sens::ErrorType for MockSensorController {
    type Error = MockSensorError;
}

impl temp::TemperatureSensor for MockSensorController {
    async fn temperature(&mut self) -> Result<DegreesCelsius, Self::Error> {
        self.sensor.temperature().await
    }
}
impl temp::TemperatureThresholdSet for MockSensorController {
    async fn set_temperature_threshold_low(&mut self, threshold: DegreesCelsius) -> Result<(), Self::Error> {
        self.sensor.set_temperature_threshold_low(threshold).await

    }

    async fn set_temperature_threshold_high(&mut self, threshold: DegreesCelsius) -> Result<(), Self::Error> {
        self.sensor.set_temperature_threshold_high(threshold).await
    }
}

impl ts::sensor::Controller for MockSensorController {}
impl ts::sensor::CustomRequestHandler for MockSensorController {}



// --------------------
#[cfg(test)]
use ec_common::test_helper::join_signals;
#[allow(unused_imports)]
use embassy_executor::Executor;
#[allow(unused_imports)]
use embassy_sync::signal::Signal;
#[allow(unused_imports)]
use static_cell::StaticCell;
#[allow(unused_imports)]
use embedded_services::power::policy::DeviceId;
#[allow(unused_imports)]
use ec_common::mutex::{Mutex, RawMutex};

// Tests that don't need async
#[test]
fn threshold_crossings_and_hysteresis() {
    // Build a controller with a default sensor
    static DEVICE: StaticCell<MockSensorDevice> = StaticCell::new();
    static CONTROLLER: StaticCell<MockSensorController> = StaticCell::new();
    let device = DEVICE.init(MockSensorDevice::new(DeviceId(1)));
    let controller = CONTROLLER.init(MockSensorController::new(device));
    let mut hi_lat = false;
    let mut lo_lat = false;

    // Program thresholds via helpers or direct fields for tests
    let (lo, hi) = (45.0_f32, 50.0_f32);

    // Script: (t, expect)
    use crate::mock_sensor_controller::ThresholdEvent::*;
    let steps = [
        (49.9, None),
        (50.1, OverHigh),
        (49.8, None),                 // still latched above-hi, no duplicate
        (49.3, None),                 // cross below hi - hyst clears latch
        (44.9, UnderLow),
        (45.3, None),                 // cross above low + hyst clears latch
    ];

    for (t, want) in steps {
        let got = controller.eval_thresholds(t, lo, hi, &mut hi_lat, &mut lo_lat);
        assert_eq!(got, want, "t={t}°C");
    }
}

// Tests that need async tasks --
#[test]
fn test_controller() {
    static EXECUTOR: StaticCell<Executor> = StaticCell::new();

    static DEVICE: StaticCell<MockSensorDevice> = StaticCell::new();
    static CONTROLLER: StaticCell<MockSensorController> = StaticCell::new();

    static TSV_DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();

    let executor = EXECUTOR.init(Executor::new());

    let tsv_done = TSV_DONE.init(Signal::new());

    executor.run(|spawner| {        
        let device = DEVICE.init(MockSensorDevice::new(DeviceId(1)));
        let controller = CONTROLLER.init(MockSensorController::new(device));

        let _ = spawner.spawn(test_setting_values(controller, tsv_done));
 
        join_signals(&spawner, [
            // vis_done,
            tsv_done
        ]);
    });
}

// check initial state, then
// set temperature, thresholds low and high, check sync with the underlying state
#[embassy_executor::task]
async fn test_setting_values(
    controller: &'static mut MockSensorController,
    done: &'static Signal<RawMutex, ()>
) 
{
    // verify initial state
    assert_eq!(0.0, controller.sensor.get_temperature());
    assert_eq!(f32::NEG_INFINITY, controller.sensor.get_threshold_low());
    assert_eq!(f32::INFINITY, controller.sensor.get_threshold_high());

    let temp = 12.34;
    let low = -56.78;
    let hi = 67.89;
    controller.sensor.set_temperature(temp);
    let _ = controller.set_temperature_threshold_low(low).await;
    let _ = controller.set_temperature_threshold_high(hi).await;
    let rtemp = controller.temperature().await.unwrap();
    assert_eq!(rtemp, temp);
    assert_eq!(controller.sensor.get_threshold_low(), low);
    assert_eq!(controller.sensor.get_threshold_high(), hi);

    done.signal(());
}
```

Likewise, update `thermal_project/mock_thermal/src/mock_fan_controller.rs` to this:
```rust

use core::future::Future;
use crate::mock_fan::{MockFan, MockFanError};
use crate::mock_fan_device::MockFanDevice;
use embedded_services::power::policy::device::Device;

use embedded_fans_async as fans;
use embedded_fans_async::{Fan, RpmSense};
use thermal_service as ts;

use ec_common::events::{CoolingRequest, CoolingResult, SpinUp};

/// Policy Configuration values for behavior logic
#[derive(Debug, Clone, Copy)]
pub struct FanPolicy {
    /// Max discrete cooling level (e.g., 10 means levels 0..=10).
    pub max_level: u8,
    /// Step per Increase/Decrease (in “levels”).
    pub step: u8,
    /// If going 0 -> >0, kick the fan to at least this RPM briefly.
    pub min_start_rpm: u16,
    /// The level you jump to on the first Increase from 0.
    pub start_boost_level: u8,
    /// How long to hold the spin-up RPM before dropping to level RPM.
    pub spinup_hold_ms: u32,
}

impl Default for FanPolicy {
    fn default() -> Self {
        Self {
            max_level: 10,
            step: 2,
            min_start_rpm: 1200,
            start_boost_level: 3,
            spinup_hold_ms: 300,
        }
    }
}

/// Linear mapping helper: level (0..=max) → PWM % (0..=100).
#[inline]
pub fn level_to_pwm(level: u8, max_level: u8) -> u8 {
    if max_level == 0 { return 0; }
    ((level as u16 * 100) / (max_level as u16)) as u8
}

/// Percentage mapping helper: pick a percentage of the range
#[inline]
pub fn percent_to_rpm_range(min: u16, max: u16, percent: u8) -> u16 {
    let p = percent.min(100) as u32;
    let span = (max - min) as u32;
    min + (span * p / 100) as u16
}
/// Percentage mapping helper: pick a percentage of the max
#[inline]
pub fn percent_to_rpm_max(max: u16, percent: u8) -> u16 {
    (max as u32 * percent.min(100) as u32 / 100) as u16
}
/// Core policy: pure, no I/O. Call this from your controller when you receive a cooling request.
/// Later, if `spinup` is Some, briefly force RPM, then set RPM to `target_rpm_percent`.
pub fn apply_cooling_request(cur_level: u8, req: CoolingRequest, policy: &FanPolicy) -> CoolingResult {
    // Sanitize policy
    let max = policy.max_level.max(1);
    let step = policy.step.max(1);
    let boost = policy.start_boost_level.clamp(1, max);

    let mut new_level = cur_level.min(max);
    let mut spinup = None;

    match req {
        CoolingRequest::Increase => {
            if new_level == 0 {
                new_level = boost;
                spinup = Some(SpinUp { rpm: policy.min_start_rpm, hold_ms: policy.spinup_hold_ms });
            } else {
                new_level = new_level.saturating_add(step).min(max);
            }
        }
        CoolingRequest::Decrease => {
            new_level = new_level.saturating_sub(step);
        }
    }

    CoolingResult {
        new_level,
        target_rpm_percent: level_to_pwm(new_level, max),
        spinup,
    }
}

pub struct MockFanController {
    pub fan: &'static mut MockFan,
    pub device: &'static mut Device
}

/// Fan controller.
///
/// This type implements [`embedded_fans_async::Fan`] and **inherits** the default
/// implementations of [`Fan::set_speed_percent`] and [`Fan::set_speed_max`].
///
/// Those methods are available on `MockFanController` without additional code here.
impl MockFanController {
    pub fn new(device: &'static mut MockFanDevice) -> Self {
        let (fan, device) = device.get_internals();
        Self {
            fan,
            device
        }
    }

    /// Execute behavior policy for a cooling request
    pub async fn handle_request(
        &mut self,
        cur_level: u8,
        req: CoolingRequest,
        policy: &FanPolicy,
    ) -> Result<(CoolingResult, u16), MockFanError> {
        let res = apply_cooling_request(cur_level, req, policy);
        if let Some(sp) = res.spinup {
            // 1) force RPM to kick the rotor
            let _ = self.set_speed_rpm(sp.rpm).await?;
            // 2) hold for `sp.hold_ms` with embassy_time to allow spin up first
            embassy_time::Timer::after(embassy_time::Duration::from_millis(sp.hold_ms as u64)).await;
        }
        let pwm = level_to_pwm(res.new_level, policy.max_level);
        let rpm = self.set_speed_percent(pwm).await?;
        Ok((res, rpm))
    }
}

impl fans::ErrorType for MockFanController {
    type Error = MockFanError;
}

impl fans::Fan for MockFanController {
    fn min_rpm(&self) -> u16 {
        self.fan.min_rpm()
    }


    fn max_rpm(&self) -> u16 {
        self.fan.max_rpm()
    }

    fn min_start_rpm(&self) -> u16 {
        self.fan.min_start_rpm()
    }

    fn set_speed_rpm(&mut self, rpm: u16) -> impl Future<Output = Result<u16, Self::Error>> {
        self.fan.set_speed_rpm(rpm)
    }
}

impl fans::RpmSense for MockFanController {
    fn rpm(&mut self) -> impl Future<Output = Result<u16, Self::Error>> {
        self.fan.rpm()
    }
}

// Allow thermal service to drive us with default linear ramp
impl ts::fan::CustomRequestHandler for MockFanController {}
impl ts::fan::RampResponseHandler for MockFanController {}
impl ts::fan::Controller for MockFanController {}

// --------------------
#[cfg(test)]
use ec_common::test_helper::join_signals;
#[allow(unused_imports)]
use embassy_executor::Executor;
#[allow(unused_imports)]
use embassy_sync::signal::Signal;
#[allow(unused_imports)]
use static_cell::StaticCell;
#[allow(unused_imports)]
use embedded_services::power::policy::DeviceId;
#[allow(unused_imports)]
use ec_common::mutex::{Mutex, RawMutex};

// Tests that don't need async
#[test]
fn increase_from_zero_triggers_spinup_then_levels() {
    let p = FanPolicy { min_start_rpm: 1000, spinup_hold_ms: 250, ..FanPolicy::default() };
    let r1 = apply_cooling_request(0, CoolingRequest::Increase, &p);
    assert_eq!(r1.new_level, 3);
    assert_eq!(r1.target_rpm_percent, 30);
    assert_eq!(r1.spinup, Some(SpinUp { rpm: 1000, hold_ms: 250 }));

    // Next increase: no spinup, just step
    let r2 = apply_cooling_request(r1.new_level, CoolingRequest::Increase, &p);
    assert_eq!(r2.new_level, 5);
    assert_eq!(r2.spinup, None);
}

#[test]
fn saturates_at_bounds_and_is_idempotent_at_extremes() {
    let p = FanPolicy::default();

    // Clamp at max
    let r = apply_cooling_request(10, CoolingRequest::Increase, &p);
    assert_eq!(r.new_level, 10);
    assert_eq!(r.spinup, None);

    // Clamp at 0
    let r = apply_cooling_request(1, CoolingRequest::Decrease, &p);
    assert_eq!(r.new_level, 0);
    let r = apply_cooling_request(0, CoolingRequest::Decrease, &p);
    assert_eq!(r.new_level, 0);
}

#[test]
fn mapping_to_rpm_is_linear_and_total() {
    assert_eq!(level_to_pwm(0, 10), 0);
    assert_eq!(level_to_pwm(5, 10), 50);
    assert_eq!(level_to_pwm(10, 10), 100);
}

// Tests that need async tasks --
#[test]
fn test_setting_values() {
    static EXECUTOR: StaticCell<Executor> = StaticCell::new();
    static DEVICE: StaticCell<MockFanDevice> = StaticCell::new();
    static CONTROLLER: StaticCell<MockFanController> = StaticCell::new();
    static DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();

    let executor = EXECUTOR.init(Executor::new());
    let done = DONE.init(Signal::new());

    executor.run(|spawner| {       
        let device = DEVICE.init(MockFanDevice::new(DeviceId(1)));
        let controller = CONTROLLER.init(MockFanController::new(device));

        // run these tasks sequentially
        let _ = spawner.spawn(setting_values_test_task(controller, done));
        join_signals(&spawner, [done]);
    });
}
#[test]
fn test_handle_request() {
    static EXECUTOR: StaticCell<Executor> = StaticCell::new();
    static DEVICE: StaticCell<MockFanDevice> = StaticCell::new();
    static CONTROLLER: StaticCell<MockFanController> = StaticCell::new();
    static DONE: StaticCell<Signal<RawMutex, ()>> = StaticCell::new();

    let executor = EXECUTOR.init(Executor::new());
    let done = DONE.init(Signal::new());

    executor.run(|spawner| {       
        let device = DEVICE.init(MockFanDevice::new(DeviceId(1)));
        let controller = CONTROLLER.init(MockFanController::new(device));

        // run these tasks sequentially
        let _ = spawner.spawn(handle_request_test_task(controller, done));
        join_signals(&spawner, [done]);
    });
}

// check initial state, then
// set temperature, thresholds low and high, check sync with the underlying state
#[embassy_executor::task]
async fn setting_values_test_task(
    controller: &'static mut MockFanController,
    done: &'static Signal<RawMutex, ()>
) 
{
    use crate::virtual_fan::{FAN_RPM_MINIMUM, FAN_RPM_MAXIMUM, FAN_RPM_START};
    // verify initial state
    let rpm = controller.rpm().await.unwrap();
    let min = controller.min_rpm();
    let max = controller.max_rpm();
    let min_start = controller.min_start_rpm();
    assert_eq!(rpm, 0);
    assert_eq!(min, FAN_RPM_MINIMUM);
    assert_eq!(max, FAN_RPM_MAXIMUM);
    assert_eq!(min_start, FAN_RPM_START);

    // now set values and verify them
    let _ = controller.set_speed_max().await;
    let v = controller.rpm().await.unwrap();
    assert_eq!(v, FAN_RPM_MAXIMUM);
    let _ = controller.set_speed_percent(50).await;
    let v = controller.rpm().await.unwrap();
    assert_eq!(v, FAN_RPM_MAXIMUM / 2);
    let _ = controller.set_speed_rpm(0).await;
    let v = controller.rpm().await.unwrap();
    assert_eq!(v, 0);

    done.signal(());
}

#[embassy_executor::task]
async fn handle_request_test_task(
    controller: &'static mut MockFanController,
    done: &'static Signal<RawMutex, ()>
) {
    let policy = FanPolicy { min_start_rpm: 1000, spinup_hold_ms: 0, ..Default::default() };

    // Start from 0, request Increase -> expect spinup and final RPM for boost level
    let (res1, rpm1) = controller.handle_request(0, CoolingRequest::Increase, &policy).await.unwrap();
    assert!(res1.spinup.is_some(), "should spin up from 0");
    assert_eq!(res1.new_level, policy.start_boost_level);

    // Final RPM should match the percent mapping for the new level
    let expect1 = percent_to_rpm_max(controller.max_rpm(), level_to_pwm(res1.new_level, policy.max_level));
    assert_eq!(rpm1, expect1);

    // Next increase -> no spinup; just step up by `step`
    let (res2, rpm2) = controller.handle_request(res1.new_level, CoolingRequest::Increase, &policy).await.unwrap();
    assert!(res2.spinup.is_none());
    assert_eq!(res2.new_level, (res1.new_level + policy.step).min(policy.max_level));

    let expect2 = percent_to_rpm_max(controller.max_rpm(), level_to_pwm(res2.new_level, policy.max_level));
    assert_eq!(rpm2, expect2);

    done.signal(());    
}
```

We mentioned that we originally implemented `MockBatteryController` as being constructed without a `Device` element, but we _will_ need to access this device context later, so we should expose that as public member in the same way.  While we are at it, we should also eliminate the generic design of the structure definition, since it is only adding unnecessary complexity and inconsistency.

Update `battery_project/mock_battery/mock_battery_controller.rs` so that it now looks like this (consistent with the others):

```rust
use battery_service::controller::{Controller, ControllerEvent};
use battery_service::device::{DynamicBatteryMsgs, StaticBatteryMsgs};
use embassy_time::{Duration, Timer}; 
use crate::mock_battery::{MockBattery, MockBatteryError};
use crate::mock_battery_device::MockBatteryDevice;
use embedded_services::power::policy::device::Device;
use embedded_batteries_async::smart_battery::{
    SmartBattery, ErrorType,
    ManufactureDate, SpecificationInfoFields, CapacityModeValue, CapacityModeSignedValue,
    BatteryModeFields, BatteryStatusFields,
    DeciKelvin, MilliVolts
};

pub struct MockBatteryController {
    /// The underlying battery instance that this controller manages.
    pub battery: &'static mut MockBattery,
    pub device: &'static mut Device

}

impl MockBatteryController
{
    pub fn new(battery_device: &'static mut MockBatteryDevice) -> Self {
        let (battery, device) = battery_device.get_internals();
        Self {
            battery,
            device
        }
    }
}

impl ErrorType for MockBatteryController
{
    type Error = MockBatteryError;
}
impl SmartBattery for MockBatteryController
{
    async fn temperature(&mut self) -> Result<DeciKelvin, Self::Error> {
        self.battery.temperature().await
    }

    async fn voltage(&mut self) -> Result<MilliVolts, Self::Error> {
        self.battery.voltage().await
    }

    async fn remaining_capacity_alarm(&mut self) -> Result<CapacityModeValue, Self::Error> {
        self.battery.remaining_capacity_alarm().await
    }

    async fn set_remaining_capacity_alarm(&mut self, _: CapacityModeValue) -> Result<(), Self::Error> {
        self.battery.set_remaining_capacity_alarm(CapacityModeValue::MilliAmpUnsigned(0)).await
    }

    async fn remaining_time_alarm(&mut self) -> Result<u16, Self::Error> {
        self.battery.remaining_time_alarm().await
    }

    async fn set_remaining_time_alarm(&mut self, _: u16) -> Result<(), Self::Error> {
        self.battery.set_remaining_time_alarm(0).await
    }

    async fn battery_mode(&mut self) -> Result<BatteryModeFields, Self::Error> {
        self.battery.battery_mode().await
    }

    async fn set_battery_mode(&mut self, _: BatteryModeFields) -> Result<(), Self::Error> {
        self.battery.set_battery_mode(BatteryModeFields::default()).await
    }

    async fn at_rate(&mut self) -> Result<CapacityModeSignedValue, Self::Error> {
        self.battery.at_rate().await
    }

    async fn set_at_rate(&mut self, _: CapacityModeSignedValue) -> Result<(), Self::Error> {
        self.battery.set_at_rate(CapacityModeSignedValue::MilliAmpSigned(0)).await
    }

    async fn at_rate_time_to_full(&mut self) -> Result<u16, Self::Error> {
        self.battery.at_rate_time_to_full().await
    }

    async fn at_rate_time_to_empty(&mut self) -> Result<u16, Self::Error> {
        self.battery.at_rate_time_to_empty().await
    }

    async fn at_rate_ok(&mut self) -> Result<bool, Self::Error> {
        self.battery.at_rate_ok().await
    }

    async fn current(&mut self) -> Result<i16, Self::Error> {
        self.battery.current().await
    }

    async fn average_current(&mut self) -> Result<i16, Self::Error> {
        self.battery.average_current().await
    }

    async fn max_error(&mut self) -> Result<u8, Self::Error> {
        self.battery.max_error().await
    }

    async fn relative_state_of_charge(&mut self) -> Result<u8, Self::Error> {
        self.battery.relative_state_of_charge().await
    }

    async fn absolute_state_of_charge(&mut self) -> Result<u8, Self::Error> {
        self.battery.absolute_state_of_charge().await
    }

    async fn remaining_capacity(&mut self) -> Result<CapacityModeValue, Self::Error> {
        self.battery.remaining_capacity().await
    }

    async fn full_charge_capacity(&mut self) -> Result<CapacityModeValue, Self::Error> {
        self.battery.full_charge_capacity().await
    }

    async fn run_time_to_empty(&mut self) -> Result<u16, Self::Error> {
        self.battery.run_time_to_empty().await
    }

    async fn average_time_to_empty(&mut self) -> Result<u16, Self::Error> {
        self.battery.average_time_to_empty().await
    }

    async fn average_time_to_full(&mut self) -> Result<u16, Self::Error> {
        self.battery.average_time_to_full().await
    }

    async fn charging_current(&mut self) -> Result<u16, Self::Error> {
        self.battery.charging_current().await
    }

    async fn charging_voltage(&mut self) -> Result<u16, Self::Error> {
        self.battery.charging_voltage().await
    }

    async fn battery_status(&mut self) -> Result<BatteryStatusFields, Self::Error> {
        self.battery.battery_status().await
    }

    async fn cycle_count(&mut self) -> Result<u16, Self::Error> {
        self.battery.cycle_count().await
    }

    async fn design_capacity(&mut self) -> Result<CapacityModeValue, Self::Error> {
        self.battery.design_capacity().await
    }

    async fn design_voltage(&mut self) -> Result<u16, Self::Error> {
        self.battery.design_voltage().await
    }

    async fn specification_info(&mut self) -> Result<SpecificationInfoFields, Self::Error> {
        self.battery.specification_info().await
    }

    async fn manufacture_date(&mut self) -> Result<ManufactureDate, Self::Error> {
        self.battery.manufacture_date().await
    }   

    async fn serial_number(&mut self) -> Result<u16, Self::Error> {
        self.battery.serial_number().await
    }

    async fn manufacturer_name(&mut self, buf: &mut [u8]) -> Result<(), Self::Error> {
        self.battery.manufacturer_name(buf).await
    }

    async fn device_name(&mut self, buf: &mut [u8]) -> Result<(), Self::Error> {
        self.battery.device_name(buf).await
    }

    async fn device_chemistry(&mut self, buf: &mut [u8]) -> Result<(), Self::Error> {
        self.battery.device_chemistry(buf).await
    }    
}

impl Controller for MockBatteryController
{
    type ControllerError = MockBatteryError;

    async fn initialize(&mut self) -> Result<(), Self::ControllerError> {
        Ok(())
    }

    async fn get_static_data(&mut self) -> Result<StaticBatteryMsgs, Self::ControllerError> {
        let mut name = [0u8; 21];
        let mut device = [0u8; 21];
        let mut chem = [0u8; 5];

        // println!("MockBatteryController: Fetching static data");

        self.battery.manufacturer_name(&mut name).await?;
        self.battery.device_name(&mut device).await?;
        self.battery.device_chemistry(&mut chem).await?;

        let capacity = match self.battery.design_capacity().await? {
            CapacityModeValue::MilliAmpUnsigned(v) => v,
            _ => 0,
        };

        let voltage = self.battery.design_voltage().await?;

        // This is a placeholder, replace with actual logic to determine chemistry ID
        // For example, you might have a mapping of chemistry names to IDs       
        let chem_id = [0x01, 0x02]; // example
        
        // Serial number is a 16-bit value, split into 4 bytes
        // where the first two bytes are zero   
        let raw = self.battery.serial_number().await?;
        let serial = [0, 0, (raw >> 8) as u8, (raw & 0xFF) as u8];

        Ok(StaticBatteryMsgs {
            manufacturer_name: name,
            device_name: device,
            device_chemistry: chem,
            design_capacity_mwh: capacity as u32,
            design_voltage_mv: voltage,
            device_chemistry_id: chem_id,
            serial_num: serial,
        })
    }    


    async fn get_dynamic_data(&mut self) -> Result<DynamicBatteryMsgs, Self::ControllerError> {
        // println!("MockBatteryController: Fetching dynamic data");

        // Pull values from SmartBattery trait
        let full_capacity = match self.battery.full_charge_capacity().await? {
            CapacityModeValue::MilliAmpUnsigned(val) => val as u32,
            _ => 0,
        };

        let remaining_capacity = match self.battery.remaining_capacity().await? {
            CapacityModeValue::MilliAmpUnsigned(val) => val as u32,
            _ => 0,
        };

        let battery_status = {
            let status = self.battery.battery_status().await?;
            // Bit masking matches the SMS specification
            let mut result: u16 = 0;
            result |= (status.fully_discharged() as u16) << 0;
            result |= (status.fully_charged() as u16) << 1;
            result |= (status.discharging() as u16) << 2;
            result |= (status.initialized() as u16) << 3;
            result |= (status.remaining_time_alarm() as u16) << 4;
            result |= (status.remaining_capacity_alarm() as u16) << 5;
            result |= (status.terminate_discharge_alarm() as u16) << 7;
            result |= (status.over_temp_alarm() as u16) << 8;
            result |= (status.terminate_charge_alarm() as u16) << 10;
            result |= (status.over_charged_alarm() as u16) << 11;
            result |= (status.error_code() as u16) << 12;
            result
        };

        let relative_soc_pct = self.battery.relative_state_of_charge().await? as u16;
        let cycle_count = self.battery.cycle_count().await?;
        let voltage_mv = self.battery.voltage().await?;
        let max_error_pct = self.battery.max_error().await? as u16;
        let charging_voltage_mv = 0; // no charger implemented yet
        let charging_current_ma = 0; // no charger implemented yet
        let battery_temp_dk = self.battery.temperature().await?;
        let current_ma = self.battery.current().await?;
        let average_current_ma = self.battery.average_current().await?;

        // For now, placeholder sustained/max power
        let max_power_mw = 0;
        let sus_power_mw = 0;

        Ok(DynamicBatteryMsgs {
            max_power_mw,
            sus_power_mw,
            full_charge_capacity_mwh: full_capacity,
            remaining_capacity_mwh: remaining_capacity,
            relative_soc_pct,
            cycle_count,
            voltage_mv,
            max_error_pct,
            battery_status,
            charging_voltage_mv,
            charging_current_ma,
            battery_temp_dk,
            current_ma,
            average_current_ma,
        })
    }        

    async fn get_device_event(&mut self) -> ControllerEvent {
        loop {
            Timer::after(Duration::from_secs(60)).await;
        }
    }

    async fn ping(&mut self) -> Result<(), Self::ControllerError> {
        Ok(())
    }

    fn get_timeout(&self) -> Duration {
        Duration::from_secs(10)
    }

    fn set_timeout(&mut self, _duration: Duration) {
        // Ignored for mock
    }
}
```

Now we have a consistent and rational pattern to each of our controller models.

As previously mentioned, note that these changes break the constructor calling in the previous example exercises, so if you are intent on keeping the previous exercises building, you will need to refactor those.
You would need to change any references to MockBatteryController<MockBattery> in any of the existing code that uses the former version to be simply `MockBatteryController` and will need to update any calls to the constructor to pass the `MockBatteryDevice` instance instead of `MockBattery`.
There are likely other ramifications with regard to multiple borrows that still remain in the previous code that you will have to choose how to mitigate as well.









