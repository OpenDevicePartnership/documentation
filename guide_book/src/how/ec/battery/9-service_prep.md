# Battery Service Preparation

We've successfully exposed and proven our implementation of battery traits and their values for our mock battery,
and built for an embedded target.
In this step, we'll continue our integration by connecting to a battery service, but that requires some setup to cover first.

## Battery-service
The ODP repository `embedded-services` has the `battery-service` we need for this, as well as the power-policy infrastructure support that uses it.

We already have our `embedded-batteries` submodule in our project space from the first steps. We'll do the same thing to bring in what we need from `embedded-services`.

We will also need the repositories `embedded-cfu`, and `embedded-usb-pd` although we won't really be using the features of these while we are in a non-embedded (std) build environment, the dependencies are still needed for reference by the other dependencies.

The same is also true for Embassy, since some of the embassy_time traits are used by ODP signatures we will be attaching to.

In the `battery_project` directory:

```cmd
git submodule add https://github.com/OpenDevicePartnership/embedded-services
git submodule add https://github.com/OpenDevicePartnership/embedded-cfu
git submodule add https://github.com/OpenDevicePartnership/embedded-usb-pd
git submodule add https://github.com/embassy-rs/embassy.git 
```

### Checking the repository examples
Within the `embedded-services` repository files, you will find a directory named `examples`.  We can find files in the `examples/std/src/bin/` folder that speak to battery and power_policy implementations, as well as other concerns.  You should familiarize yourself with these examples.

In this exercise we will be borrowing from those designs in a curated fashion.
If at any time there is question about the implementation presented in this exercise, please consult the examples in the repository, as they may contain updated information.

### A Mock Battery Device
To fit the design of the ODP battery service, we first need to create a wrapper that contains our MockBattery and a Device Trait.  We need to implement `DeviceContainer` for this wrapper and reference that `Device`.
Then we will register the wrapper with `register_device(...)` and we will have an async loop that awaits commands on the `Device`'s `channel`, executes them, and updates state.

#### Import the battery-service from the ODP crate
One of the service definitions from the `embedded-services` repository we brought into scope is the `battery-service`. 
We now need to update our Cargo.toml to know where to find it.
Open the `Cargo.toml` file of your mock-battery project and add the dependency to the battery-service path.  We will also need a reference to `embedded-services` itself for various support needs.
We will no longer be requiring `tokio`, so you can remove that dependency, but we do need to import crate references from `embassy`.
Update your `mock_battery/Cargo.toml` so that your `[dependencies]` section now looks like this to include references we will need.

Your new `[dependencies]` section should now look like this:

```toml
[dependencies]
embedded-batteries-async = { path = "../embedded-batteries/embedded-batteries-async" }
battery-service = { path = "../embedded-services/battery-service" }
embedded-services = { path = "../embedded-services/embedded-service" }
embassy-executor = { workspace = true }
embassy-time = { workspace = true, features=["std"] }
embassy-sync = { workspace = true, features=["std"] }
critical-section = {version = "1.0", features = ["std"] }
async-trait = "0.1"
# tokio = { version = "1.45", features = ["full"] }
static_cell = "1.0"
once_cell = { workspace = true }
```
This will allow us to import what we need for the next steps.

### Top-level Cargo.toml
Note that some of these dependencies say 'workspace = true'.  This implies they are in the workspace as configured by our top-level Cargo.toml, at `battery_project/Cargo.toml`.
We need to update our top-level Cargo.toml to include these.  In `battery_project/Cargo.toml` add this section and settings:

```toml
[workspace.dependencies]
embassy-executor = { path = "embassy/embassy-executor", features = ["arch-std", "executor-thread"], default-features = false }
embassy-time = { path = "embassy/embassy-time" }
embassy-futures = "0.1.0"
embassy-sync = "0.7.0"
embassy-time-driver = "0.2.0"
embedded-hal = "1.0"
embedded-hal-async = "1.0"
```
and you will want to add this section as well.  This tells cargo to use our local submodule version of embassy rather than reaching out to crates-io for a version:

```toml
[patch.crates-io]
embassy-executor = { path = "embassy/embassy-executor"}
embassy-time = { path = "embassy/embassy-time" }
embassy-time-driver = { path = "embassy/embassy-time-driver" }
embassy-time-queue-utils = { path = "embassy/embassy-time-queue-utils" }
```
But we are not done yet.
If we execute `cargo build` at this point, we will likely get an error that says there was an "error inheriting `once_cell` from workspace root manifest's `workspace.dependencies.once_cell`

We can solve that by adding that reference to `[workspace.dependencies]`
```toml
once_cell = "1.19"
```

Still not done.
If we execute `cargo build` at this point, we will likely get an error that says there was an "error inheriting `defmt` from workspace root manifest's `workspace.dependencies.defmt`" and "`workspace.dependencies` was not defined".

This is because these dependencies are used by the dependencies that we have included, even if we aren't using them ourselves.  In many cases, such as those dependencies that are relying on packages like `embassy` for embedded support, we won't be using at all in our 'std' build environment, and these will be compiled out of our build as a result, but they must still be referenced to satisfy the dependency chain.

To remedy this, we must edit the top-level Cargo.toml (`battery_project/cargo.toml`) to include a reference to `defmt`, such as 
```toml
[workspace.dependencies]
defmt = "1.0"
```
and when you try again, you will get another error specifying the next missing dependency reference.  Add these placeholder references in the same way.  For now, don't worry about the version.  Make each reference = "1.0".

For references to dependencies we _are_ using in our project (`embedded-batteries`, `embedded-batteries-async`, `embedded-services`, `battery-service`), specify these by providing their path, as in:
```toml
embedded-batteries-async = { path = "embedded-batteries/embedded-batteries-async" }
embedded-services = { path = "embedded-services/embedded-service" }
battery-service = { path = "embedded-services/battery-service" }
embedded-cfu-protocol = { path = "embedded-cfu" }
embedded-usb-pd = { path = "embedded-usb-pd" }
```
Once all the dependencies have been named, `cargo build` will start to complain about acceptable version numbers for those where the "1.0" placeholder will not suffice.  For example:

```
error: failed to select a version for the requirement `embassy-executor = "^1.0"`
candidate versions found which didn't match: 0.7.0, 0.6.3, 0.6.2, ...
```
So in these cases, change the "1.0" to one of the versions from the list ("0.7.0")

After doing all of this, your `[workspace.dependencies]` section will look something like this:
```toml
[workspace.dependencies]
embassy-executor = { path = "embassy/embassy-executor", features = ["arch-std", "executor-thread"], default-features = false }
embassy-time = { path = "embassy/embassy-time" }
embassy-futures = "0.1.0"
embassy-sync = "0.7.0"
embassy-time-driver = "0.2.0"
embedded-hal = "1.0"
embedded-hal-async = "1.0"
once_cell = "1.19"
defmt = "1.0"
log = "0.4.27"
bitfield = "0.19.1"
bitflags = "1.0"
bitvec = "1.0"
cfg-if = "1.0"
chrono = "0.4.41"
critical-section = {version = "1.0", features = ["std"] }
document-features = "0.2.11"
embedded-hal-nb = "1.0"
embedded-io = "0.6.1"
embedded-io-async = "0.6.1"
embedded-storage = "0.3.1"
embedded-storage-async = "0.4.1"
fixed = "1.0"
heapless = "0.8.0"
postcard = "1.0"
rand_core = "0.9.3"
serde = "1.0"
cortex-m = "0.7.7"
cortex-m-rt = "0.7.5"
embedded-batteries = { path = "embedded-batteries/embedded-batteries" }
embedded-batteries-async = { path = "embedded-batteries/embedded-batteries-async" }
embedded-services = { path = "embedded-services/embedded-service" }
battery-service = { path = "embedded-services/battery-service" }
embedded-cfu-protocol = { path = "embedded-cfu" }
embedded-usb-pd = { path = "embedded-usb-pd" }
```

_(Note: the entries above also include dependencies for some items we will need in upcoming steps and haven't encountered yet)_

Insure `cargo clean` and `cargo build` succeeds with your dependencies referenced accordingly before proceeding to the next step.

### Define the MockBatteryDevice wrapper

In your mock_battery project `src` folder, create a new file named `mock_battery_device.rs` and give it this content:

```rust
use crate::mock_battery::MockBattery;
use embedded_services::power::policy::DeviceId;
use embedded_services::power::policy::action::device::AnyState;
use embedded_services::power::policy::device::{
    Device, DeviceContainer, CommandData, ResponseData//, State
};


pub struct MockBatteryDevice {
    #[allow(dead_code)] // Prevent unused warning for MockBattery -- not used yet   
    battery: MockBattery,
    device: Device,
}

impl MockBatteryDevice {
    pub fn new(id: DeviceId) -> Self {
    Self {
            battery: MockBattery::new(),
            device: Device::new(id)
        }
    }

    pub fn device(&self) -> &Device {
        &self.device
    }

    pub fn inner_battery(&mut self) -> &mut MockBattery {
        &mut self.battery
    }   

    pub async fn run(&self) {
        loop {
            let cmd = self.device.receive().await;

            // Access command using the correct method
            let request = &cmd.command; 

            match request {
                CommandData::ConnectAsConsumer(cap) => {
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

                CommandData::ConnectAsProvider(cap) => {
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

- Imported what we need from the ODP repositories for both the SmartBattery definition from `embedded-batteries_async` and the battery service components from `embedded-services` crates as as our own local MockBattery definition.

- Defined and implemented our MockBatteryDevice
- implemented a run loop for our MockBatteryDevice

Note we have some `println!` statements here to echo when certain events occur.  These won't be seen until later, but we want feedback when we do hook things up in our pre-test example.

#### Including mock_battery_device
Just like we had to inform the build of our mock_battery and virtual_battery, we need to do likewise with mock_battery_device.  So edit `lib.rs` into this:
```rust
pub mod mock_battery;
pub mod virtual_battery;
pub mod mock_battery_device;```

After you've done all that,  you should be able to build with 
```
cargo build
```
and get a clean result
_Note: if you commented out or removed the reference to `tokio` in your `Cargo.toml` you may need to put that back to compile against the existing `main.rs`, but we will be replacing `main.rs` shortly._

Next we will work to put this battery to use.

