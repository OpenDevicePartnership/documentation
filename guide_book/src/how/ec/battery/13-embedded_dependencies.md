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

Replace the current contents of `main.rs` with this code, which will choose between the two:
```
#![cfg_attr(feature = "embedded", no_std)]

#[cfg(all(feature = "desktop", not(feature = "embedded")))]
mod desktop_main;

#[cfg(all(feature = "embedded", not(feature = "desktop")))]
mod embedded_main;

#[cfg(all(feature = "desktop", not(feature = "embedded")))]
fn main() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(desktop_main::run());
}

#[cfg(all(feature = "embedded", not(feature = "desktop")))]
fn main() {
    embedded_main::run();
}
```
And then, finally, from the `battery_project` root,
build the desktop version with 
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

We shouldn't be emitting console messages here anyway. 
The proper way to check the features of something like our SmartBattery Device implementation for MockBatteryDevice
is through well-defined Unit Tests.

We'll be doing that in the next section.


