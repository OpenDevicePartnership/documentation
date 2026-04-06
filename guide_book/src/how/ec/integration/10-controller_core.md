# ControllerCore

Now we are ready to implement the core of our integration, the `ControllerCore` structure and its associated tasks and trait implementations.  This is where the bulk of our integration logic will reside.

Our `ControllerCore` implementation will consist of four primary areas of concern:

1. basic implementation of collected components
2. Controller trait implementation
3. spawned tasks, including listeners that accept messages
4. handlers that conduct the actions related to messages received.

The first two of these are necessary to implement in order to create a minimally viable first test.

Let's start out with the basic implementation of `controller_core.rs` by starting with this code:
```rust
use mock_battery::mock_battery_controller::MockBatteryController;
use mock_charger::mock_charger_controller::MockChargerController;
use crate::config::ui_config::RenderMode;
use crate::system_observer::SystemObserver;
use crate::entry::{BatteryChannelWrapper, ChargerChannelWrapper, InteractionChannelWrapper, ThermalChannelWrapper};

use battery_service::controller::{Controller, ControllerEvent};
use battery_service::device::{DynamicBatteryMsgs, StaticBatteryMsgs};
use embassy_time::Duration; 
use mock_battery::mock_battery::MockBatteryError;
use embedded_batteries_async::smart_battery::{
    SmartBattery,
    ManufactureDate, SpecificationInfoFields, CapacityModeValue, CapacityModeSignedValue,
    BatteryModeFields, BatteryStatusFields,
    DeciKelvin, MilliVolts
};

use embedded_services::power::policy::charger::Device as ChargerDevice; // disambiguate from other device types
use embedded_services::power::policy::PowerCapability;
use embedded_services::power::policy::charger::PolicyEvent;
use embedded_services::power::policy::charger::ChargerResponseData;

use ec_common::mutex::{Mutex, RawMutex};
use crate::display_models::StaticValues;
use crate::events::{BusEvent, InteractionEvent};
use ec_common::events::ThermalEvent;
use embedded_services::power::policy::charger::{ChargerEvent, PsuState};
use embassy_sync::channel::{Channel, Sender, Receiver, TrySendError};

use embassy_executor::Spawner;

use embedded_batteries_async::charger::{Charger, MilliAmps};
use embedded_services::power::policy::charger::{
    ChargeController,ChargerError
};
use mock_charger::mock_charger::MockChargerError;

const BUS_CAP: usize = 32;

use crate::config::AllConfig;
use crate::state::{ChargerState, SimState};

use crate::setup_and_tap::INTERNAL_SAMPLE_BUF_LENGTH;

use thermal_service as ts;
use ts::sensor as tss;
use ts::fan   as tsf;


#[allow(unused)]
pub struct ControllerCore { 
    // device components
    pub battery: MockBatteryController,         // controller tap is owned by battery service wrapper
    pub charger: MockChargerController, 
    // ODP wrappers, not raw controllers
    pub sensor: &'static tss::Sensor<mock_thermal::mock_sensor_controller::MockSensorController, {INTERNAL_SAMPLE_BUF_LENGTH}>,
    pub fan:    &'static tsf::Fan<mock_thermal::mock_fan_controller::MockFanController, {INTERNAL_SAMPLE_BUF_LENGTH}>,
    // for charger service
    pub charger_service_device: &'static ChargerDevice,

    // comm busses
    pub battery_channel: &'static BatteryChannelWrapper,  // owned by setup and shared   
    pub charger_channel: &'static ChargerChannelWrapper,
    pub thermal_channel: &'static ThermalChannelWrapper,
    pub interaction_channel: &'static InteractionChannelWrapper,

    tx:Sender<'static, RawMutex, BusEvent, BUS_CAP>,
    
    // ui observer
    pub sysobs: &'static SystemObserver,    // owned by setup and shared 

    // configuration
    pub cfg: AllConfig,

    // state
    pub sim: SimState,
    pub chg: ChargerState
    
}

static BUS: Channel<RawMutex, BusEvent, BUS_CAP> = Channel::new();

impl ControllerCore {
    pub fn new(
        battery: MockBatteryController, 
        charger: MockChargerController,
        sensor: &'static tss::Sensor<mock_thermal::mock_sensor_controller::MockSensorController, {INTERNAL_SAMPLE_BUF_LENGTH}>,
        fan: &'static tsf::Fan<mock_thermal::mock_fan_controller::MockFanController, {INTERNAL_SAMPLE_BUF_LENGTH}>,
        charger_service_device: &'static ChargerDevice,
        battery_channel: &'static BatteryChannelWrapper,
        charger_channel: &'static ChargerChannelWrapper,
        thermal_channel: &'static ThermalChannelWrapper,
        interaction_channel: &'static InteractionChannelWrapper,
        sysobs: &'static SystemObserver,
    ) -> Self
    {  
        Self {
            battery, charger, sensor, fan,
            charger_service_device,
            battery_channel, charger_channel, thermal_channel, interaction_channel,
            tx: BUS.sender(),
            sysobs,
            cfg: AllConfig::default(),
            sim: SimState::default(),
            chg: ChargerState::default()
        }
    }

    // === API for message senders ===
    /// No-await event emit
    #[allow(unused)]
    pub fn try_send(&self, evt: BusEvent) -> Result<(), TrySendError<BusEvent>> {
        self.tx.try_send(evt)
    }

    /// Awaiting send for must-deliver events.
    #[allow(unused)]
    pub async fn send(&self, evt: BusEvent) {
        self.tx.send(evt).await
    }

    /// start event processing with a passed mutex 
    pub fn start(core_mutex: &'static Mutex<RawMutex, ControllerCore>, spawner: Spawner) {
        
        println!("In ControllerCore::start()"); 
    }
}
```

Now, you will recall that we created `BatteryAdapter` as a structure implementing all the traits required for it to serve as the component registered for the Battery Service (via the `BatteryWrapper`), and that this implementation simply passed these traits along to this `ControllerCore` instance, so we must necessarily implement all those trait methods here in `ControllerCore` as well.  Since we have our actual Battery object contained here, we can forward these in turn to that component, thus attaching it to the Battery Service.  But along the way, we get the opportunity to "tap into" this relay and use this opportunity to conduct our integration business.

As noted briefly earlier, we could choose to not implement these traits here.  In the end the `ControllerCore` does not really need to "look like a battery controller" -- it just needs to handle key methods triggered by the tr

Let's go ahead and implement these traits  by adding this code to `controller_core.rs` now.
This looks long, but most of it is just pass-through to the underlying battery and charger components (remember how extensive the `SmartBattery` traits are):

```rust
// ================= traits ==================
impl embedded_batteries_async::smart_battery::ErrorType for ControllerCore
{
    type Error = MockBatteryError;
}

impl SmartBattery for ControllerCore
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

    async fn set_remaining_capacity_alarm(&mut self, v: CapacityModeValue) -> Result<(), Self::Error> {
        self.battery.set_remaining_capacity_alarm(v).await
    }

    async fn remaining_time_alarm(&mut self) -> Result<u16, Self::Error> {
        self.battery.remaining_time_alarm().await
    }

    async fn set_remaining_time_alarm(&mut self, v: u16) -> Result<(), Self::Error> {
        self.battery.set_remaining_time_alarm(v).await
    }

    async fn battery_mode(&mut self) -> Result<BatteryModeFields, Self::Error> {
        self.battery.battery_mode().await
    }

    async fn set_battery_mode(&mut self, v: BatteryModeFields) -> Result<(), Self::Error> {
        self.battery.set_battery_mode(v).await
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

    async fn manufacturer_name(&mut self, v: &mut [u8]) -> Result<(), Self::Error> {
        self.battery.manufacturer_name(v).await
    }

    async fn device_name(&mut self, v: &mut [u8]) -> Result<(), Self::Error> {
        self.battery.device_name(v).await
    }

    async fn device_chemistry(&mut self, v: &mut [u8]) -> Result<(), Self::Error> {
        self.battery.device_chemistry(v).await
    }    
}


// helper works for Vec<u8>, &Vec<u8>, &[u8], [u8; N], heapless::String, etc.
fn to_string_lossy<B: AsRef<[u8]>>(b: B) -> String {
    String::from_utf8_lossy(b.as_ref()).into_owned()
}

// Implement the same trait the wrapper expects.
impl Controller for ControllerCore {


    type ControllerError = MockBatteryError;

    async fn initialize(&mut self) -> Result<(), Self::ControllerError> {
        Ok(())
    }

    async fn get_static_data(&mut self) -> Result<StaticBatteryMsgs, Self::ControllerError> {
        println!("🥳 >>>>> get_static_data has been called!!! <<<<<<");
        self.battery.get_static_data().await

    }

    async fn get_dynamic_data(&mut self) -> Result<DynamicBatteryMsgs, Self::ControllerError> {
        println!("🥳 >>>>> get_dynamic_data has been called!!! <<<<<<");
        self.battery.get_dynamic_data().await
    }

    async fn get_device_event(&mut self) -> ControllerEvent {
        println!("🥳 >>>>> get_device_event has been called!!! <<<<<<");
        core::future::pending().await
    }

    async fn ping(&mut self) -> Result<(), Self::ControllerError> {
        println!("🥳 >>>>> ping has been called!!! <<<<<<");
        self.battery.ping().await

    }

    fn get_timeout(&self) -> Duration {
        println!("🥳 >>>>> get_timeout has been called!!! <<<<<<");
        self.battery.get_timeout()
    }

    fn set_timeout(&mut self, duration: Duration) {
        println!("🥳 >>>>> set_timeout has been called!!! <<<<<<");
        self.battery.set_timeout(duration)
    }
}

// --- charger ---
impl embedded_batteries_async::charger::ErrorType for ControllerCore 
{
    type Error = MockChargerError;
}

impl Charger for ControllerCore
{
    fn charging_current(
        &mut self,
        requested_current: MilliAmps,
    ) -> impl core::future::Future<Output = Result<MilliAmps, Self::Error>> {
        self.charger.charging_current(requested_current)
    }

    fn charging_voltage(
        &mut self,
        requested_voltage: MilliVolts,
    ) -> impl core::future::Future<Output = Result<MilliVolts, Self::Error>> {
        self.charger.charging_voltage(requested_voltage)
    }
}

impl ChargeController for ControllerCore 
{
    type ChargeControllerError = ChargerError;

    fn wait_event(&mut self) -> impl core::future::Future<Output = ChargerEvent> {
        async move { ChargerEvent::Initialized(PsuState::Attached) }
    }

    fn init_charger(
        &mut self,
    ) -> impl core::future::Future<Output = Result<(), Self::ChargeControllerError>> {
        self.charger.init_charger()
    }

    fn is_psu_attached(
        &mut self,
    ) -> impl core::future::Future<Output = Result<bool, Self::ChargeControllerError>> {
        self.charger.is_psu_attached()
    }

    fn attach_handler(
        &mut self,
        capability: PowerCapability,
    ) -> impl core::future::Future<Output = Result<(), Self::ChargeControllerError>> {
        self.charger.attach_handler(capability)
    }

    fn detach_handler(
        &mut self,
    ) -> impl core::future::Future<Output = Result<(), Self::ChargeControllerError>> {
        self.charger.detach_handler()
    }

    fn is_ready(
        &mut self,
    ) -> impl core::future::Future<Output = Result<(), Self::ChargeControllerError>> {
        self.charger.is_ready()
    }
}
```

By adding these traits we satisfy the interface requirements for a battery-service  / Battery Controller  implementation and also as a Charger Controller.  We have `println!` output in place to tell us when the Battery Controller traits are called from the battery-service.  These will make a good first test.

We have almost all the parts we need to run a simple test to see if things are wired up correctly.  We just need to add a few final items to get everything started.  Let's do that next.
