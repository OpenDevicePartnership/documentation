# Battery Service Preparation


---------------
_TODO: 
This section needs to be revisited and rewritten to support a successful 'standard' build - earlier attempts at 
including some of the dependencies in a std environment failed, and so this was written to build for the embedded target
at this premature phase.  We want to build the battery complete before switching to the embedded context though._

-----------------

We've successfully exposed and proven our implementation of battery traits and their values for our mock battery,
and built for an embedded target.
In this step, we'll continue our integration by connecting to a battery service, but that requires some setup to cover first.

## Battery-service
The ODP repository `embedded-services` has the `battery-service` we need for this, as well as the power-policy infracture support that uses it.

The ODP repository `embedded-cfu` is also needed here,
as is `embedded-usb-pd`.

We will bring these into our scope now.

In the `battery_project`, we'll bring these in with the commands:

```
git submodule add https://github.com/OpenDevicePartnership/embedded-services

git submodule add git@github.com:OpenDevicePartnership/embedded-cfu

git submodule add git@github.com:OpenDevicePartnership/embedded-usb-pd

```


### A Mock Battery Device
To fit the design of the ODP battery service, we first need to create a wrapper that contains our MockBattery and a Device Trait.  We need to implement `DeviceContainer` for this wrapper and reference that `Device`.
Then we will register the wrapper with `register_device(...)` and we will have an async loop that awaits commands on the `Device`'s `channel`, executes them, and updates state.

#### Import the battery-service from the ODP crate
One of the service definitions from the `embedded-services` repository we brought into scope is the `battery-service`. 
We now need to update our Cargo.toml to know where to find it.
Open the `Cargo.toml` file of your mock-battery project and add the dependency to the battery-service path to our Cargo.toml.  We will also need a reference to `embedded-services` itself for various support needs.  Update your `mock_battery/Cargo.toml` so that your `[dependencies]` section now looks like this:

```
[dependencies]
cortex-m-rt = "0.7.3"
static_cell = "2.0.0"
embedded-batteries = { path = "../embedded-batteries/embedded-batteries" }
embedded-batteries-async = { path = "../embedded-batteries/embedded-batteries-async" }
battery-service = { path = "../embedded-services/battery-service" }
embedded-services = { path = "../embedded-services/embedded-service" }
```
This will allow us to import what we need for the next steps.

### Define the MockBatteryDevice wrapper

In your mock_battery project `src` folder, create a new file named `mock_battery_device.rs` and give it this content:

```
use crate::mock_battery::MockBattery;
use embedded_services::power::policy::DeviceId;
use embedded_services::power::policy::action::device::AnyState;
use embedded_services::power::policy::device::{
    Device, DeviceContainer, CommandData, ResponseData//, State
};
// use embedded_services::intrusive_list::Node;


pub struct MockBatteryDevice {
    #[allow(dead_code)] // Prevent unused warning for MockBattery -- not used yet   
    battery: MockBattery,
    device: Device,
}

impl MockBatteryDevice {
    pub fn new(id: DeviceId) -> Self {
    Self {
            battery: MockBattery,
            device: Device::new(id)
        }
    }

    pub fn device(&self) -> &Device {
        &self.device
    }

    pub async fn run(&self) {
        loop {
            let cmd = self.device.receive().await;

            // Access command using the correct method
            let request = &cmd.command; 

            match request {
                CommandData::ConnectConsumer(_cap) => {
                    // println!("Received ConnectConsumer for {}mA @ {}mV", cap.current_ma, cap.voltage_mv);

                    // Safe placeholder: detach any existing state
                    match self.device.device_action().await {
                        AnyState::ConnectedProvider(dev) => {
                            if let Err(_e) = dev.detach().await {
                                // println!("Detach failed: {:?}", e);
                            }
                        }
                        AnyState::ConnectedConsumer(dev) => {
                            if let Err(_e) = dev.detach().await {
                                // println!("Detach failed: {:?}", e);
                            }
                        }
                        _ => (),
                    }

                    cmd.respond(Ok(ResponseData::Complete));
                }

                CommandData::ConnectProvider(_cap) => {
                    // println!("Received ConnectProvider for {}mA @ {}mV", cap.current_ma, cap.voltage_mv);

                    match self.device.device_action().await {
                        AnyState::ConnectedProvider(dev) => {
                            if let Err(_e) = dev.detach().await {
                                // println!("Detach failed: {:?}", e);
                            }
                        }
                        AnyState::ConnectedConsumer(dev) => {
                            if let Err(_e) = dev.detach().await {
                                // println!("Detach failed: {:?}", e);
                            }
                        }
                        _ => (),
                    }

                    cmd.respond(Ok(ResponseData::Complete));
                }

                CommandData::Disconnect => {
                    // println!("Received Disconnect");

                    match self.device.device_action().await {
                        AnyState::ConnectedProvider(dev) => {
                            if let Err(_e) = dev.detach().await {
                                // println!("Detach failed: {:?}", e);
                            }
                        }
                        AnyState::ConnectedConsumer(dev) => {
                            if let Err(_e) = dev.detach().await {
                                // println!("Detach failed: {:?}", e);
                            }
                        }
                        _ => {
                            // println!("Already disconnected or idle");
                        }
                    }

                    cmd.respond(Ok(ResponseData::Complete));
                }
            }
        }
    }
}

impl DeviceContainer for MockBatteryDevice {
    fn get_power_policy_device(&self) -> &Device {
        &self.device
    }
}
```
What we've done here is:

- Imported what we need from the ODP repositories for both the SmartBattery definition from `embedded-batteries` and the battery service components from `embedded-services` crates as as our own local MockBattery definition.

- Define and implement our MockBatteryDevice
- implement a run loop for our MockBatteryDevice

Note also there are some commented-out `println!` macros. We can't use `println!` in our embedded context, but we'll deal with that later. For now these comments serve as placeholders.

#### Including mock_battery_device
Just like we had to inform the build of our mock_battery, we need to do likewise with mock_battery_device.  So edit `lib.rs` and to this:
```
#![no_std]
pub mod mock_battery;
pub mod mock_battery_device;
```

__Important__: Note that we also added `#![no_std]` at the top of this `lib.rs` file.  This is necessary to insure that our build is not expecting the defaults from std to be available.

#### Updating the dependencies
We now must make some edits to our top-level `battery_project/Cargo.toml` file to reflect the new dependencies.

Add the references to our embedded-services dependencies to `members` list of the `[workspace]` section so it now has all our new members:
```
members = [
    "mock_battery",
    "embedded-batteries/embedded-batteries",
    "embedded-batteries/embedded-batteries-async",
    "embedded-services/embedded-service",
    "embedded-services/battery-service",
    "embedded-cfu",
    "embedded-usb-pd",
    "embassy/embassy-executor",
    "embassy/embassy-futures",
    "embassy/embassy-sync",
    "embassy/embassy-time",
    "embassy/embassy-time-driver"
]
```
and create a new `[workspace.depedencies]` section in this file as well:
```
[workspace.dependencies]
embedded-services = { path = "embedded-services/embedded-service" }
```
This reconciles the name from 'embedded-service' to 'embedded-services'.

## 🛠️🧩 Dependency Detour: Manual Overrides Required 🧩 🛠️
At this point, you'll encounter a wall of configuration. 
If you try to build here you will get an error about an failure to inherit a workspace dependency or else a dependency not found.  This is due to the need to match the configurations for the crates we are importing.  You can use tools like `cargo search` to show the current version of dependencies, for example, and tackle these one at a time, but in the interest of efficiency, just copy what is shown here, because there is a lot.

Unfortunately, the current structure of the service crates requires us to explicitly patch and align many transitive dependencies to avoid conflicts—especially around async runtime and HAL crates.

This may feel excessive, but it’s a one-time setup step to align everything cleanly for builds targeting either desktop or embedded systems. Once it’s in place, the rest of the work proceeds smoothly.

Your top-level Cargo.toml at `battery_project/Cargo.toml` should have a full `[workspace.dependencies]` section that looks like this:

```
[workspace.dependencies]
embedded-services = { path = "embedded-services/embedded-service" }
defmt = "1.0"
embassy-executor = { path = "embassy/embassy-executor" }
embassy-futures = { path = "embassy/embassy-futures" }
embassy-sync = { path = "embassy/embassy-sync" }
embassy-time = { path = "embassy/embassy-time" }
embassy-time-driver = { path = "embassy/embassy-time-driver" }
embedded-batteries-async = { path = "embedded-batteries/embedded-batteries-async" }
embedded-cfu-protocol = { path = "embedded-cfu" }
embedded-usb-pd = { path = "embedded-usb-pd" }

embedded-hal = "1.0.0"
embedded-hal-async = "1.0.0"
log = "0.4"
bitfield = "0.17.0"
bitflags = "2.8.0"
bitvec = { version = "1.0.1", default-features = false }
cfg-if = "1.0.0"
chrono = { version = "0.4", default-features = false }
cortex-m = "0.7.6"
cortex-m-rt = "0.7.5"
critical-section = "1.1"
document-features = "0.2.7"                    
embedded-hal-nb = "1.0.0"
embedded-io = "0.6.1"
embedded-io-async = "0.6.1"
embedded-storage = "0.3.0"
embedded-storage-async = "0.3.0"
rand_core = "0.9.3"
heapless = { version = "0.7.16", default-features = false }
fixed = { version = "1.23.1", default-features = false }
postcard = { version = "1.1.1", default-features = false }
serde = { version = "1.0.219", default-features = false, features = ["derive"] }
```
After you've done all that,  you should be able to build with 
```
cargo build --target thumbv7em-none-eabihf
```
and get a clean result

Next we will work to put this battery to use.

