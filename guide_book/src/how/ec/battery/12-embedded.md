# Building for the Embedded Target

We've validated our simplistic mock battery has implemented basic traits, and we've been able to do that with a generic build on the desktop.
To go much further, we need to start building for the embedded controller context that this component is designed to run as - targeted for a microcontroller, without standard library dependencies.

Which development board we use at this point isn’t critical. Our mock battery and simulated components will remain software-only for now, so we don’t need physical hardware peripherals or a fully implemented HAL. Later, when we explore advanced features like ARM TrustZone or Hafnium hypervisor integration, we may need a specific Cortex-M board — but those can be hard to source. So rather than lock ourselves in too early, we’ll keep this next section general and adaptable to what you may already have.

In particular, if you've followed the excellent  [Rust Embedded Book](https://docs.rust-embedded.org/book/), there's a good chance you already have an STM32 Discovery board on hand. These boards are inexpensive, well-supported, and ideal for this stage of development.

The examples here will use the STM32F3 Discovery board. If you're using a different board, you may need to adjust your configuration accordingly. That said, our code will aim to be as portable and HAL-independent as possible.

## Getting Set Up

To build for an embedded target, we need to prepare our development environment with a few important tools and configuration files.

While there are many variations depending on target board and host OS, we will aim to keep this setup as broadly compatible and standard as possible.

### Installing the Embedded Rust Toolchain

The standard Rust toolchain needs a few additions to suppor cross-compiling for emedded targets.

Staying within your current `battery_project` workspace, 
run
```
rustup target add thumbv7em-none-eabihf
```

### Including Embassy
Many of the embedded features supported by ODP rely on dependencies of Embassy, and we will also want to use many of Embassy's framework support to simplify our construction.
To keep things as consistent as possible, we will be bringing in the Embassy repository as another submodule, similar to what we did with `embedded-batteries`

At the `battery_project` root:
```
git submodule add https://github.com/embassy-rs/embassy.git
```

### Updating the configuration files

In `mock_battery/Cargo.toml`, update the contents to look like this:

```
[package]
name = "mock_battery"
version = "0.1.0"
edition = "2024"


[dependencies]
embedded-batteries = { path = "../embedded-batteries/embedded-batteries" }
embassy-executor = { path = "../embassy/embassy-executor", optional = true }

[features]
default = ["embedded"]
embedded = ["embassy-executor"]
```

At the top-level Cargo.toml (`battery_project/Cargo.toml`), update the workspace members to include the new local crates:
```
members = [
    "mock_battery",
    "embedded-batteries/embedded-batteries",
    "embassy/embassy-executor"
]
```
Now you should be able to build with
```
cargo build
```

That should build properly. 
Now let's see if we can target our embedded toolchain.
enter
```
cargo build --target thumbv7em-none-eabihf
```
This will produce a number of errors because we still have the old `println!` statements in there from the previous example.
We also need to better prepare the code for a "no-std" environment.

Replace the current `main.rs` content with this new version:
```
#![no_std]
#![no_main]

use embedded_batteries::smart_battery::SmartBattery;
use mock_battery::mock_battery::MockBattery;
use cortex_m_rt::entry;

#[entry]
fn main() -> ! {
    let mut battery = MockBattery;

    let _ = battery.voltage();
    let _ = battery.relative_state_of_charge();
    let _ = battery.temperature();

    loop {}
}

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
```

You can see we're not only not printing anything to the output here, we have specifically declared `#![no_std]` and provided a `#[panic_handler]` that normally would be supplied by std.

One more thing to do.  In `lib.rs`, add `#![no_std]` at the top of that file as well.
```
#![no_std]
pub mod mock_battery;
```

Now
```
cargo build --target thumbv7em-none-eabihf
```
should build without issue.

In the next section, we will look at writing Unit Tests to prove out the behaviors of our mock battery and provide some simulation of charge behaviors.



