# A Mock Battery Project

In previous pages, we saw how the _Smart Battery Specification (SBS)_ defines a set of functions that a Smart Battery service should implement.

In the next pages, we are going to review how these traits are defined in Rust within the [embedded-services repository](https://github.com/OpenDevicePartnership/embedded-services/), and we are going to import these structures into our own workspace as we build our mock battery.
In subsequent steps we'll connect the battery into the supporting upstream EC service framwork.

## Setting up for development
We are going to create a project space that contains a folder for our battery code, and the dependent repository clones.

We'll refer to this as __`battery_project`__.

So, start by finding a suitable location on your local computer and create the workspace:

```
mkdir battery_project
cd battery_project
git init
```
This will create a workspace root for us and establish it as a git repository (not attached).

Now, we are going to bring the embedded-batteries directory
into our workspace and build the crates it exports.

_(from the `battery_project` directory):_
```
git submodule add https://github.com/OpenDevicePartnership/embedded-batteries
```

The `embedded-batteries` repository has the subsystem service definitions for the battery defined in both 
`embedded-batteries` and `embedded-batteries-async` crates.  We are going to use the async variant here because this is required when attaching later to the `Controller`, which we will attach our battery implementation into the larger service framework.


Now, we can create our project space and start our own work.  Within the battery_project directory, create a folder named mock_battery and give it this project structure.  This will allow us to organize our own modules and dependencies cleanly:

```
mock_battery/
  src/ 
   - lib.rs
   - mock_battery.rs
  Cargo.toml 
  
Cargo.toml  
```
note there are two `Cargo.toml` files here. One is within the `battery_project` root folder and the other is at the root of `mock_battery`.  The `mock_battery.rs` file resides within the `mock_battery/src` directory.

The contents of the `battery_project/Cargo.toml` file should contain:

```toml
[workspace]
resolver = "2"
members = [
    "mock_battery"
]

```
and the contents of the `battery_project/mock_battery/Cargo.toml` file should be set to:

```toml
[package]
name = "mock_battery"
version = "0.1.0"
edition = "2024"


[dependencies]
embedded-batteries-async = { path = "../embedded-batteries/embedded-batteries-async" }
```

This structure and the `Cargo.toml` definitions just define a minimal skeleton for the dependencies we will be adding to as we continue to build our mock battery implementation and work it into the larger ODP framework.

The `lib.rs` file is used to tell Rust which modules are part of the project. Set it's contents to:
```
pub mod mock_battery;
```

the `mock_battery.rs` file can be empty for now.  We will define its contents in the next step.

