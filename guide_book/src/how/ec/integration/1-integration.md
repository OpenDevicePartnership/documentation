# Integration

We've built a collection of components.  Now, we want to make sure that we have a working integration of the components in a virtual environment. This will allow us to test the interactions between the components and ensure that they work together as expected, which is crucial step before the components can move closer to a real-world implementation in hardware.

In this section, we will cover the integration of all of our example components working together. 
This integration will be similar to the previous examples, but with some additional complexity due to the interaction between the components. We will also explore how to test the integration of these components and ensure that they work together as expected. In the process, we will also make a more engaging, interactive application for evaluating our combined creation locally.

## About the Battery-Charger Integration
In our previous integration exercise, we realized we needed to restructure much of our project structure to allow proper code accessibility to build the integration.
Refactoring is a normal part of a development process as complexity grows and patterns of component interoperability begin to emerge. 
We did restructure the code in that effort. However, for the most part, we simply moved ahead with the same service integration and message handling established with the very first component creation.  This included introducing ownership-rule defying patterns such as the `duplicate_static_mut!` copy macro that allowed us to get around Rust rules for double-borrow.  We could assert that this was safe because we could audit all the uses ourselves and verify that no harm would come, even though Rust's static analysis, unable to share that birdseye view of things, would not agree.  But these forms of assertions all too easily become overconfident declarations of hubris and just because we _say_ something is safe, doesn't mean it is, especially when components begin getting plugged together in various new ways, and especially in an environment that strives for seamless interchangeability of component models.  

_After all, what is the point of the type-safe advantages in Rust when you choose to treat it like C?_

In this integration -- where we bring together all of the components we have created, we want to make sure we have a strong and defensible integration model design before
we move on to embedded targeting where flaws in our design will be less tolerated.

Several parts of our previous integrations, on review, are flawed:
- The already mentioned use of `unsafe` code workarounds and inconsistent ownership patterns.
- Unnecessary use of Generics when constructing components.  Generics come with additional overhead and are more complicated to write for, so use of them superficially should be discouraged.
- Failure to use the `battery-service` event processing - even though we created and registered our BatteryDevice, we didn't start the service that uses it.

## A more unified structure
A problem we have seen that quickly becomes even more complicated as we bring this integration together is the issue of a single, unified ownership scope. We've already noted how having separate component instances that we try to pass around to various worker tasks runs quickly into the multiple borrow violations problem.

To combat this more structurally, we'll define a single structure, `ControllerCore`, that will own all of the components directly, and access to this at a task level will be managed by a mutex to ensure we don't run into any race condition behavior. These patterns are enforceable by Rust's static analysis, so if it complains, we know we've crossed a line and shouldn't resort to cheating with `unsafe` casts or else we will face consequences.

>## New approach benefits
> - single owner `ControllerCore`
> - consolidated BusEvent channel for messages
> - OnceLock + Mutex pattern
> - removal of gratuitous generics
> ----

### Breaking some eggs
Addressing these changes will require some minor revisions in our previous definitions for `MockBatteryController` and `MockChargerController`.  Although the changes are minor, they will have significant impact upon the previous projects and they will no longer build. As they say, making omelets requires breaking some eggs.  These past projects could be resurrected by adopting some of the new constructor patterns we will introduce here, but that will be left as an exercise for the reader.

## A simulation
We will build this integration as both an integration test and as an executable app that runs the simulation of the components in action. This simulator will allow us to increase/decrease the load, mimicking the behavior of a real system, and we can then observe how the components interact with each other to keep the battery charged and the system cool over differing operating conditions.

### Setting up the integration project
We will set up a new project space for this integration, rather than trying to shoehorn it into the existing battery or charger projects. This will allow us to keep the integration code separate from the component code, making it easier to manage and test.

Create a new project directory in the `ec_examples` directory named `integration_project`.  Give it a `Cargo.toml` file with the following content:

```toml
# Integration Project
[package] 
name = "integration_project"
version = "0.1.0"
edition = "2024"
resolver = "2"
description = "System-level integration sim wiring Battery, Charger, and Thermal"


[dependencies]
embedded-batteries-async    = { workspace = true }
embassy-executor            = { workspace = true }
embassy-time                = { workspace = true }
embassy-sync                = { workspace = true }
embassy-futures             = { workspace = true }
embassy-time-driver         = { workspace = true }
embassy-time-queue-utils    = { workspace = true }

embedded-services           = { workspace = true }
battery-service             = { workspace = true }
embedded-sensors-hal-async  = {workspace = true}
embedded-fans-async         = {workspace = true}
thermal-service             = {workspace = true}


ec_common       = { path = "../ec_common"}
mock_battery    = { path = "../battery_project/mock_battery", default-features = false}
mock_charger    = { path = "../charger_project/mock_charger", default-features = false}
mock_thermal    = { path = "../thermal_project/mock_thermal", default-features = false}

static_cell = "2.1"
futures     = "0.3"
heapless    = "0.8"
crossterm   = "0.27"

[features]
default = ["std", "thread-mode"]
std = []
thread-mode = [
    "mock_battery/thread-mode",
    "mock_charger/thread-mode",
    "mock_thermal/thread-mode"
]
noop-mode = [
    "mock_battery/noop-mode",
    "mock_charger/noop-mode",
    "mock_thermal/noop-mode"
]
```

Next, edit the `ec_examples/Cargo.toml` at the top level to add `integration_project` as a workspace member:

```toml
 members = [
    "battery_project/mock_battery",
    "charger_project/mock_charger",
    "thermal_project/mock_thermal",
    "battery_charger_subsystem",
    "integration_project",
    "ec_common"
]
```

We also need to add a couple more references to the `[patch.crates-io]` section to ensure cargo refers to the same crates across the board:
```toml
embedded-sensors-hal-async = { path = "embedded-sensors/embedded-sensors-async"}  
embedded-fans-async = { path = "embedded-fans/embedded-fans-async"}
```

_As a reminder, the whole of `ec_examples/Cargo.toml` looks like this:_

```toml
# ec_examples/Cargo.toml
[workspace]
resolver = "2"
members = [
    "battery_project/mock_battery",
    "charger_project/mock_charger",
    "thermal_project/mock_thermal",
    "battery_charger_subsystem",
    "integration_project",
    "target-integration_project",
    "ec_common"
]

[workspace.dependencies]
embedded-services = { path = "embedded-services/embedded-service" }
battery-service = { path = "embedded-services/battery-service" }
embedded-batteries = { path = "embedded-batteries/embedded-batteries" }
embedded-batteries-async = { path = "embedded-batteries/embedded-batteries-async" }
embedded-cfu-protocol = { path = "embedded-cfu" }
embedded-usb-pd = { path = "embedded-usb-pd" }

thermal-service = { path = "embedded-services/thermal-service" } 
embedded-sensors-hal-async = { path = "embedded-sensors/embedded-sensors-async"}
embedded-fans-async = { path = "embedded-fans/embedded-fans-async"}

embassy-executor = { path = "embassy/embassy-executor", features = ["arch-std", "executor-thread"], default-features = false }
embassy-time = { path = "embassy/embassy-time", features=["std"], default-features = false }
embassy-sync = { path = "embassy/embassy-sync", features = ["std"] }
embassy-futures = { path = "embassy/embassy-futures" }
embassy-time-driver = { path = "embassy/embassy-time-driver", default-features = false}
embassy-time-queue-utils = { path = "embassy/embassy-time-queue-utils" }
embedded-hal = "1.0"
embedded-hal-async = "1.0"
once_cell = "1.19"
static_cell = "2.1.0"
defmt = "1.0"
log = "0.4.27"
bitfield = "0.19.1"
bitflags = "1.0"
bitvec = "1.0"
cfg-if = "1.0"
chrono = "0.4.41"
tokio = { version = "1.45", features = ["full"] }
uuid = "1.0"
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

[patch.crates-io]
embassy-executor = { path = "embassy/embassy-executor" }
embassy-time = { path = "embassy/embassy-time" }
embassy-sync = { path = "embassy/embassy-sync" }
embassy-futures = { path = "embassy/embassy-futures" }
embassy-time-driver = { path = "embassy/embassy-time-driver" }
embassy-time-queue-utils = { path = "embassy/embassy-time-queue-utils" }
embedded-batteries-async = { path = "embedded-batteries/embedded-batteries-async" }
embedded-sensors-hal-async = { path = "embedded-sensors/embedded-sensors-async"}  
embedded-fans-async = { path = "embedded-fans/embedded-fans-async"}

# Lint settings for the entire workspace.
# We start with basic warning visibility, especially for upcoming Rust changes.
# Additional lints are listed here but disabled by default, since enabling them
# may trigger warnings in upstream submodules like `embedded-services`.
#
# To tighten enforcement over time, you can uncomment these as needed.
[workspace.lints.rust]
warnings = "warn"              # Show warnings, but do not fail the build
future_incompatible = "warn"  # Highlight upcoming breakage (future Rust versions)
# rust_2018_idioms = "warn"     # Enforce idiomatic Rust style (may warn on legacy code)
# unused_crate_dependencies = "warn"  # Detect unused deps — useful during cleanup
# missing_docs = "warn"       # Require documentation for all public items
# unsafe_code = "deny"        # Forbid use of `unsafe` entirely

[patch.'https://github.com/embassy-rs/embassy']
embassy-time = { path = "./embassy/embassy-time" }
embassy-time-driver = { path = "./embassy/embassy-time-driver" }
embassy-sync = { path = "./embassy/embassy-sync" }
embassy-executor = { path = "./embassy/embassy-executor" }
embassy-futures = { path = "./embassy/embassy-futures" }
```

Now we can get on with the changes to our existing code to make things ready for this integration, starting with defining some structures for configuration to give us parametric control of behavior and policy.

