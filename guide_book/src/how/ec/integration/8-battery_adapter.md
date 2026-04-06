# Battery Adapter

The battery service expects to be handed a type that implements the `SmartBattery` trait, as well as the `Controller` trait defined in the `battery_service::controller` module.  We can create a simple adapter type that holds a reference to our `ControllerCore` mutex, and then forwards the trait method calls into the core controller code.

```rust
use crate::controller_core::ControllerCore;
#[allow(unused_imports)]
use ec_common::mutex::{RawMutex, Mutex};
use core::sync::atomic::{AtomicU64, Ordering};

#[allow(unused_imports)]
 use battery_service::controller::{Controller, ControllerEvent};
use battery_service::device::{DynamicBatteryMsgs, StaticBatteryMsgs};
use embassy_time::Duration; 
use mock_battery::mock_battery::MockBatteryError;
#[allow(unused_imports)]
 use embedded_batteries_async::smart_battery::{
     SmartBattery,
     ManufactureDate, SpecificationInfoFields, CapacityModeValue, CapacityModeSignedValue,
     BatteryModeFields, BatteryStatusFields,
     DeciKelvin, MilliVolts
 };

const DEFAULT_TIMEOUT_MS: u64 = 1000;

#[allow(unused)]
 pub struct BatteryAdapter {
    core_mutex: &'static Mutex<RawMutex, ControllerCore>,
    timeout_ms: AtomicU64 // cached timeout to work around sync/async mismatch
 }

 impl BatteryAdapter {
#[allow(unused)]
    pub fn new(core_mutex: &'static Mutex<RawMutex, ControllerCore>) -> Self {
        Self {
            core_mutex,
            timeout_ms: AtomicU64::new(DEFAULT_TIMEOUT_MS)
        }
    }

    #[inline]
    fn dur_to_ms(d: Duration) -> u64 {
        // Use the unit that’s most convenient for you; ms is usually fine.
        d.as_millis() as u64
    }

    #[inline]
    fn ms_to_dur(ms: u64) -> Duration {
        Duration::from_millis(ms as u64)
    }

    // called on Controller methods to shadow timeout value we can forward in a synchronous trait method
    fn sync_timeout_cache(&self, core: &mut ControllerCore) {
        use core::sync::atomic::Ordering;
        let cached = self.timeout_ms.load(Ordering::Relaxed);
        let current = Self::dur_to_ms(core.get_timeout());
        if current != cached {
            core.set_timeout(Self::ms_to_dur(cached));
        }
    }
    
 }

impl embedded_batteries_async::smart_battery::ErrorType for BatteryAdapter
{
    type Error = MockBatteryError;
}

 impl SmartBattery for BatteryAdapter {
    async fn temperature(&mut self) -> Result<DeciKelvin, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.temperature().await
    }

    async fn voltage(&mut self) -> Result<MilliVolts, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.voltage().await
    }

    async fn remaining_capacity_alarm(&mut self) -> Result<CapacityModeValue, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.remaining_capacity_alarm().await
    }

    async fn set_remaining_capacity_alarm(&mut self, v: CapacityModeValue) -> Result<(), Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.set_remaining_capacity_alarm(v).await
    }

    async fn remaining_time_alarm(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.remaining_time_alarm().await
    }

    async fn set_remaining_time_alarm(&mut self, v: u16) -> Result<(), Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.set_remaining_time_alarm(v).await
    }

    async fn battery_mode(&mut self) -> Result<BatteryModeFields, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.battery_mode().await
    }

    async fn set_battery_mode(&mut self, v: BatteryModeFields) -> Result<(), Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.set_battery_mode(v).await
    }

    async fn at_rate(&mut self) -> Result<CapacityModeSignedValue, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.at_rate().await
    }

    async fn set_at_rate(&mut self, _: CapacityModeSignedValue) -> Result<(), Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.set_at_rate(CapacityModeSignedValue::MilliAmpSigned(0)).await
    }

    async fn at_rate_time_to_full(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.at_rate_time_to_full().await
    }

    async fn at_rate_time_to_empty(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.at_rate_time_to_empty().await
    }

    async fn at_rate_ok(&mut self) -> Result<bool, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.at_rate_ok().await
    }

    async fn current(&mut self) -> Result<i16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.current().await
    }

    async fn average_current(&mut self) -> Result<i16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.average_current().await
    }

    async fn max_error(&mut self) -> Result<u8, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.max_error().await
    }

    async fn relative_state_of_charge(&mut self) -> Result<u8, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.relative_state_of_charge().await
    }

    async fn absolute_state_of_charge(&mut self) -> Result<u8, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.absolute_state_of_charge().await
    }

    async fn remaining_capacity(&mut self) -> Result<CapacityModeValue, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.remaining_capacity().await
    }

    async fn full_charge_capacity(&mut self) -> Result<CapacityModeValue, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.full_charge_capacity().await
    }

    async fn run_time_to_empty(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.run_time_to_empty().await
    }

    async fn average_time_to_empty(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.average_time_to_empty().await
    }

    async fn average_time_to_full(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.average_time_to_full().await
    }

    async fn charging_current(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.charging_current().await
    }

    async fn charging_voltage(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.charging_voltage().await
    }

    async fn battery_status(&mut self) -> Result<BatteryStatusFields, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.battery_status().await
    }

    async fn cycle_count(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.cycle_count().await
    }

    async fn design_capacity(&mut self) -> Result<CapacityModeValue, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.design_capacity().await
    }

    async fn design_voltage(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.design_voltage().await
    }

    async fn specification_info(&mut self) -> Result<SpecificationInfoFields, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.specification_info().await
    }

    async fn manufacture_date(&mut self) -> Result<ManufactureDate, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.manufacture_date().await
    }   

    async fn serial_number(&mut self) -> Result<u16, Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.serial_number().await
    }

    async fn manufacturer_name(&mut self, v: &mut [u8]) -> Result<(), Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.manufacturer_name(v).await
    }

    async fn device_name(&mut self, v: &mut [u8]) -> Result<(), Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.device_name(v).await
    }

    async fn device_chemistry(&mut self, v: &mut [u8]) -> Result<(), Self::Error> {
        let mut c = self.core_mutex.lock().await;
        c.device_chemistry(v).await
    }    
 }

impl Controller for BatteryAdapter {

    type ControllerError = MockBatteryError;

    async fn initialize(&mut self) -> Result<(), Self::ControllerError> {
        let mut c = self.core_mutex.lock().await;
        self.sync_timeout_cache(&mut *c); // deref + ref safely casts away the guard
        c.initialize().await
    }


    async fn get_static_data(&mut self) -> Result<StaticBatteryMsgs, Self::ControllerError> {
        let mut c = self.core_mutex.lock().await;
        self.sync_timeout_cache(&mut *c); // deref + ref safely casts away the guard
        c.get_static_data().await
    }

    async fn get_dynamic_data(&mut self) -> Result<DynamicBatteryMsgs, Self::ControllerError> {
        let mut c = self.core_mutex.lock().await;
        self.sync_timeout_cache(&mut *c); // deref + ref safely casts away the guard
        c.get_dynamic_data().await
    }

    async fn get_device_event(&mut self) -> ControllerEvent {
        core::future::pending().await
    }

    async fn ping(&mut self) -> Result<(), Self::ControllerError> {
        let mut c = self.core_mutex.lock().await;
        self.sync_timeout_cache(&mut *c); // deref + ref safely casts away the guard
        c.ping().await
    }

    fn get_timeout(&self) -> Duration {
        // Fast path: if we can grab the mutex without waiting, read the real value.
        if let Ok(guard) = self.core_mutex.try_lock() {
            let d = guard.get_timeout();                    // assumed non-async on core
            self.timeout_ms.store(Self::dur_to_ms(d), Ordering::Relaxed);
            d
        } else {
            // Fallback to cached value if the mutex is busy.
            Self::ms_to_dur(self.timeout_ms.load(Ordering::Relaxed))
        }    
    }

    fn set_timeout(&mut self, duration: Duration) {
        // Always update our cache immediately.
        self.timeout_ms.store(Self::dur_to_ms(duration), Ordering::Relaxed);

        // Try to apply to the real controller right away if the mutex is free.
        // if the mutex is busy, we'll simply use the previous cache next time.
        if let Ok(mut guard) = self.core_mutex.try_lock() {
            guard.set_timeout(duration);                    // assumed non-async on core
        }
    
 
    }
}
```
As noted, the `BatteryAdapter` is nothing more than a forwarding mechanism to direct the trait methods called by the battery service into our code base.  We pass it the reference to our `core_mutex` which is then used to call the battery controller traits implemented there, in our `ControllerCore` code.

Note that we might also have chosen to direct all but the `get_static_data` / `get_dynamic_data` trait methods of `BatteryAdapter` directly to the `MockBatteryController`, since the `ControllerCore` is going to simply forward them there anyway.


