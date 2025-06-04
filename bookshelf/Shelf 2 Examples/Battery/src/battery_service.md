# Battery Service

We've successfully exposed and proven our implementation of battery traits and their values for our mock battery.
In this step, we'll continue our integration by connecting to a battery service.

## Battery-service
The ODP repository embedded-services has the battery-service we need for this, as well as the power-policy infracture support that uses it.

We will bring that into our scope now.

In the `battery_project` directory, where you previously cloned `embedded-batteries`, now clone `embedded-services` in much the same way with the command

```
git clone git@github.com:OpenDevicePartnership/embedded-services.git
```
and then build it
```
cd embedded-services
cargo build
```

### A Mock Battery Device
To fit the design of the ODP battery service, we first need to create a wrapper that contains our MockBattery and a Device Trait.  We need to implement `DeviceContainer` for this wrapper and reference that `Device`.
Then we will register the wrapper with `register_device(...)` and we will have an async loop that awaits commands on the `Device`'s `channel`, executes them, and updates state.

#### Import the battery-service from the ODP crate
We built the crate in the previous step. We now need to remember to update our Cargo.toml to know where to find it.
Open the `Cargo.toml` file of your mock-battery project and add this battery-service path
so that your `[dependencies]` section now looks like this:

```
[dependencies]
embedded-batteries = { path = "../embedded-batteries/embedded-batteries" }
battery-service = { path = "../embedded-services/battery-service" }
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
                CommandData::ConnectConsumer(cap) => {
                    println!("Received ConnectConsumer for {}mA @ {}mV", cap.current_ma, cap.voltage_mv);

                    // Safe placeholder: detach any existing state
                    match self.device.device_action().await {
                        AnyState::ConnectedProvider(dev) => {
                            if let Err(e) = dev.detach().await {
                                println!("Detach failed: {:?}", e);
                            }
                        }
                        AnyState::ConnectedConsumer(dev) => {
                            if let Err(e) = dev.detach().await {
                                println!("Detach failed: {:?}", e);
                            }
                        }
                        _ => (),
                    }

                    cmd.respond(Ok(ResponseData::Complete));
                }

                CommandData::ConnectProvider(cap) => {
                    println!("Received ConnectProvider for {}mA @ {}mV", cap.current_ma, cap.voltage_mv);

                    match self.device.device_action().await {
                        AnyState::ConnectedProvider(dev) => {
                            if let Err(e) = dev.detach().await {
                                println!("Detach failed: {:?}", e);
                            }
                        }
                        AnyState::ConnectedConsumer(dev) => {
                            if let Err(e) = dev.detach().await {
                                println!("Detach failed: {:?}", e);
                            }
                        }
                        _ => (),
                    }

                    cmd.respond(Ok(ResponseData::Complete));
                }

                CommandData::Disconnect => {
                    println!("Received Disconnect");

                    match self.device.device_action().await {
                        AnyState::ConnectedProvider(dev) => {
                            if let Err(e) = dev.detach().await {
                                println!("Detach failed: {:?}", e);
                            }
                        }
                        AnyState::ConnectedConsumer(dev) => {
                            if let Err(e) = dev.detach().await {
                                println!("Detach failed: {:?}", e);
                            }
                        }
                        _ => {
                            println!("Already disconnected or idle");
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

#### Including embedded-services
We previously imported what we needed for the `battery-service` from `embedded-services` but now we need imports from `embedded-services` itself, so we must add this line
to the `[dependencies]` section of `mock_battery/Cargo.toml`:
```
embedded-services = { path = "../embedded-services/embedded-service" }
```

#### Including mock_battery_device
Just like we had to inform the build of our mock_battery, we need to do likewise with mock_battery_device.  So edit `lib.rs` and to this:
```
pub mod mock_battery;
pub mod mock_battery_device;
```

### Registering our device
We need to register and run our device, but here's where we need to make a deviation. The embedded-services functions expect an asynchronous model.  In our embedded target, we will no doubt want to use the async executor from [Embassy](../../3/support/embassy.html#async-executor) for this, but since for the moment we are still building and running on the desktop, we need a different option.  For desktop support, we will be using the `tokio` crate for async support.

This divergent juncture is also an excellent opportunity to demonstrate how two different implementation options might be selected using Feature flags, so we'll do that here.

#### Set up Cargo.toml
We can set up for features in `Cargo.toml` of `mock_battery` by adding this section:

```
[features]
default = ["desktop"]
desktop = ["tokio"]
embedded = ["embassy-executor"]
```
To support async, we will use Embassy for the embedded build.  This is supported by the ODP framework as well, so we will want to match it's dependencies here.

For desktop builds, we can use `tokio` for this.

We will need to import the `tokio` crate from `crates.io` to support the desktop implementation. 
We import `embassy-executor` from `git`, since this must match the one referenced by the ODP framework.

We can do that by adding these lines to our `[dependencies]` section:
```
# Optional runtimes
tokio = { version = "1", features = ["full"], optional = true }
embassy-executor = { git = "https://github.com/embassy-rs/embassy", package = "embassy-executor", features = ["arch-std","executor-thread"], optional = true }

```
we mark them as optional, because they will only be used for their repective builds.

#### Updating the dependencies
We now must make some edits to our top-level (`battery_project`) `Cargo.toml` file to reflect the new dependencies.

Add the references to `member` list of the `[workspace]` section:
```
members = [
    "mock_battery",
    "embedded-services/embedded-service",
    "embedded-services/battery-service",
    "embedded-batteries/embedded-batteries"
]
```
and create a new `[workspace.depedencies]` section in this file as well:
```
[workspace.dependencies]
embedded-services = { path = "embedded-services/embedded-service" }
```
This reconciles the name from 'embedded-service' to 'embedded-services'.

#### Unavoidable Detail Ahead: Dependency Overrides
At this point, you'll encounter a wall of configuration. Unfortunately, the current structure of the service crates requires us to explicitly patch and align many transitive dependencies to avoid conflicts—especially around async runtime and HAL crates.

This may feel excessive, but it’s a one-time setup step to align everything cleanly for builds targeting either desktop or embedded systems. Once it’s in place, the rest of the work proceeds smoothly.

Add the following lines to the `[workspace.dependencies]` section:
```
# These align versions of crates used across embedded-services, battery-service,
# and embassy dependencies to avoid mismatched or duplicated transitive dependencies.
bitfield = "0.17.0"
bitflags = "2.8.0"
bitvec = { version = "1.0.1", default-features = false }
cfg-if = "1.0.0"
chrono = { version = "0.4", default-features = false }
cortex-m = "0.7.6"
cortex-m-rt = "0.7.5"
critical-section = "1.1"
defmt = "0.3"
document-features = "0.2.7"

embassy-executor     = { git = "https://github.com/embassy-rs/embassy", package = "embassy-executor" }
embassy-futures      = { git = "https://github.com/embassy-rs/embassy", package = "embassy-futures" }
embassy-sync         = { git = "https://github.com/embassy-rs/embassy", package = "embassy-sync" }
embassy-time         = { git = "https://github.com/embassy-rs/embassy", package = "embassy-time" }
embassy-time-driver  = { git = "https://github.com/embassy-rs/embassy", package = "embassy-time-driver" }

embedded-batteries-async = { path = "embedded-batteries/embedded-batteries-async" }
embedded-cfu-protocol    = { git = "https://github.com/OpenDevicePartnership/embedded-cfu" }
embedded-hal             = "1.0"
embedded-hal-async       = "1.0"
embedded-hal-nb          = "1.0"
embedded-io              = "0.6.1"
embedded-io-async        = "0.6.1"
embedded-storage         = "0.3"
embedded-storage-async   = "0.4.1"
embedded-usb-pd          = { git = "https://github.com/OpenDevicePartnership/embedded-usb-pd", default-features = false }

fixed     = "1.23.1"
heapless  = "0.8.*"
log       = "0.4"
postcard  = "1.*"
rand_core = "0.6.4"
serde     = { version = "1.0.*", default-features = false }
tps6699x  = { git = "https://github.com/OpenDevicePartnership/tps6699x" }
```
And, finally, add this patch section so that Cargo does not try to load embassy from `crates.io` despite other declarations:

```
[patch.crates-io]
embassy-executor = { git = "https://github.com/embassy-rs/embassy", package = "embassy-executor" }
embassy-time     = { git = "https://github.com/embassy-rs/embassy", package = "embassy-time" }
embassy-sync     = { git = "https://github.com/embassy-rs/embassy", package = "embassy-sync" }
embassy-futures  = { git = "https://github.com/embassy-rs/embassy", package = "embassy-futures" }
```

You should now be able to run `cargo build` from the `battery_project` directory without errors.


#### Two versions of main
Our register-and-run main function will have two versions. One for desktop (the default, and the one we just built in the previous step), and one for embedded. 

In the `mock_battery` directory, create the file `embedded_main.rs` that we will use for our embedded target.  Give it this content:
```
use embassy_executor::Spawner;
use embedded_services::power::policy::register_device;
use embedded_services::power::policy::DeviceId;
use mock_battery::mock_battery_device::MockBatteryDevice;

#[embassy_executor::main]
async fn main(_spawner: Spawner) {

    let dev = Box::leak(Box::new(MockBatteryDevice::new(DeviceId(0))));
    
    register_device(dev).await.unwrap();
    dev.run().await;
}

pub fn run() {
    // Stub for build compatibility when running on non-embedded platform
    panic!("This binary must be built for an embedded target");
}

```
and create a file named `desktop_main.rs` with this content:
```
use embedded_services::power::policy::register_device;
use embedded_services::power::policy::DeviceId;
use mock_battery::mock_battery_device::MockBatteryDevice;


pub async fn run() {

    let dev = Box::leak(Box::new(MockBatteryDevice::new(DeviceId(0))));
    
    register_device(dev).await.unwrap();
    dev.run().await;
}

// Stub for build compatibility when running on non-embedded platform
#[cfg(feature = "desktop")]
#[unsafe(no_mangle)]
pub extern "C" fn _critical_section_1_0_acquire() {}

#[cfg(feature = "desktop")]
#[unsafe(no_mangle)]
pub extern "C" fn _critical_section_1_0_release() {}

#[cfg(feature = "desktop")]
#[unsafe(no_mangle)]
pub extern "C" fn _embassy_time_now() -> u64 {
    0
}

#[cfg(feature = "desktop")]
#[unsafe(no_mangle)]
pub extern "C" fn _embassy_time_schedule_wake(_timestamp: u64) {}
```

Build the desktop version with 
```
cargo build --features desktop
```
and build the embedded version with
```
cargo build --features embedded --no-default-features
```
Both should build without errors.

Note that `cargo build` by itself defaults to the desktop option.

The `--no-default-features` flag is required for the embedded option because of the exclusivity of the feature options.

Also note that you might optionally add ` -p mock_battery` to this command to definitively say which workspace project to build, but this will be the default anyway since it is the only one that takes these features.

#### No output
If you try to do a `cargo run` for the embedded build you will see an error that it can't do that without an embedded target -- which we will get to in good time.

If you do a `cargo run` for the desktop build you will not see any output, and will have to use `ctrl-c` to break and exit the program.

This is because we changed our main function (for both feature targets) to register and wait for commands from the service, and we haven't done that yet.  So nothing is going to appear until we do.

We'll be doing that in the next section.


