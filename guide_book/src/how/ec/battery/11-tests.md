# Unit Tests

In the previous exercises, we have built an implementation of a `SmartBattery` for our Mock Battery, and shown we can implement it into a service registry where it can be called upon by a service.

The next step is to test our implementation through a series of Unit Tests.
Unit Tests will ensure the implementation produces the results we expect.  Early on, we had simply printed some values to the console to verify certain values.  This is not a good method of testing because the print action cannot be part of the final build.  Instead, we want to use a Unit Test harness that will allow us to inspect our otherwise silent build and report the values within it.

## Why test?

We create tests for our components because we need to assert that they perform according to specification.  Unlike our `println!` output, tests are non-intrusive and do not alter the code of the system under test.  A _test framework_ is used to call into the tested code and exercise it according to procedures that provide confidence that the system being tested will perform as expected if put into a larger system.

If we decide to add new features (such as support for a removable battery), we can use the test framework to monitor our development progress.  

In fact, "Test-Driven Development" (TDD) is a proven software development approach that begins with defining the tests that match the specification of a software system and then builds the software to meet the tests.

We can also use a test framework to continue testing the component when in a different target environment, such as an embedded build.  This gives us confidence that the code we are inserting into a system is good to go, as oftentimes subtle differences emerge when cross-compiling to a target.

## Types of Tests and where to put them
A __Unit Test__ typically is scoped to test only the capabilities of a single component or "unit" of code.
An __Integration Test__ is a test that either tests different implementations of a single unit structure, or else the integration of more than one component and the interactions between these components.

Code for Integration Tests are typically in a separate .rs file (often within a 'test' directory).  Unit Tests may also be separate, but it is also conventional for Unit Tests to be included in the same Rust code file as the component code itself.
In our Mock Battery case, we will put these first tests within our mock_battery.rs file.
This keeps our tests co-located with the implementation and avoids the need for additional test scaffolding. 
If later the virtual battery or HAL layer is changed to match a different target, or the component is placed into a slightly different service structure, the tests are still valid and since they live with the code, it is good modular hygiene to include the unit tests along with the code file.
Since we're implementing traits intended for broader reuse, but are only concerned with our one MockBattery implementation for now, embedding the tests here is both practical and instructive.


## Preparing for testing
Rust's `Cargo` already supports a test framework, so there is no additional framework installation or setup needed.

However, there are some differences in the threading model that is used when we are testing using Embassy Executor.  

We need an asynchronous context for testing our asynchronous method traits, so we construct our test flow in the same way we constructed our `main()` function, and will use the Embassy `Executor` to spawn asynchronous tasks that call upon the traits we wish to test.

Due to thread and Mutex handling differences between a standard run and test framework run, we need to make a few simple refactors to our existing code so that it will handle both cases.

To do this, we will first define a helper module named `mutex.rs` with this content:
```rust
extern crate alloc;

#[cfg(test)]
pub use std::sync::Arc;
#[cfg(test)]
pub use embassy_sync::blocking_mutex::raw::NoopRawMutex as RawMutex;

#[cfg(not(test))]
pub use alloc::sync::Arc;
#[cfg(not(test))]
pub use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex as RawMutex;

// Common export regardless of test or target
pub use embassy_sync::mutex::Mutex;
```
As you can see, this chooses the definition of Arc and which RawMutex type to apply, as these have ramifications across the different environments, and does so with the management of `#[cfg(test)]` and `#[cfg(not(test))]` preprocessor directives.

Make this module known to your `lib.rs` file as well:
```rust
pub mod mock_battery;
pub mod virtual_battery;
pub mod mock_battery_device;
pub mod espi_service;
pub mod mock_battery_controller;
pub mod types;
pub mod mutex;
```

Now, we will make some replacements to use this new helper.

🗎 In `espi_service.rs`, remove the line

```rust
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
```
and replace it with
```rust
use crate::mutex::RawMutex;
```
and further down, in the declaration of `pub struct EspiService`, change
```rust
 _signal: Signal<ThreadModeRawMutex, BatteryEvent>
 ```
 to
 ```rust
  _signal: Signal<RawMutex, BatteryEvent>
  ```

🗎 In `main.rs`:

remove
```rust
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::mutex::Mutex;
```
and replace it with
```rust
use mock_battery::mutex::RawMutex;
```

and replace
```rust
 pub struct BatteryFuelReadySignal {
    signal: Signal<ThreadModeRawMutex, ()>,
 }
 ```
 with
 ```rust
  pub struct BatteryFuelReadySignal {
    signal: Signal<RawMutex, ()>,
 }

🗎 In `mock_battery.rs`:

remove the line
```rust
extern crate alloc;
```

remove the lines
```rust
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::mutex::Mutex;
use alloc::sync::Arc;
```
and replace with
```rust
use crate::mutex::{Arc, Mutex, RawMutex};
```
replace
```rust
 pub struct MockBattery {
    pub state: Arc<Mutex<ThreadModeRawMutex, VirtualBatteryState>>,
 }
 ```
 with
 ```rust
  pub struct MockBattery {
    pub state: Arc<Mutex<RawMutex, VirtualBatteryState>>,
 }```



🗎 Replace `type.rs` with:
```rust
// mock_battery/src/types.rs

use crate::mutex::RawMutex;
use embassy_sync::channel::Channel;
use battery_service::context::BatteryEvent;

pub type BatteryChannel = Channel<RawMutex, BatteryEvent, 4>;
```

🗎 in your `mock_battery/Cargo.toml` file, add this section:
```toml
[dev-dependencies]
embassy-executor = { workspace = true, version = "0.5", features = ["arch-std"] }
```

now do a `cargo clean` and `cargo build` to insure the refactoring was successful.

### Before testing

We run tests with the `cargo test` command.

If you issues a `cargo test` command now, by itself, you should see a compile step followed by a series of unit test reports for each module of the workspace, including all the dependencies.  You may also see some test warnings or failures from some of these.  Do not be concerned with these.  If you are seeing test failures from embassy-executor-macros, this is because these tests are designed against an expected embedded target.

If this bothers you, you can get a clean all-workspace test run with the command `cargo test --workspace --exclude embassy-executor-macros`

But we are not really interested in the test results of the dependent modules (unless we were planning on contributing to those projects), so we will want to run our tests confined to our own project. 

Use the command `cargo test -p mock_battery` to run the tests we define for our project.

This will report `running 0 tests` of course, because we haven't created any yet.

#### A Framework within a Framework - Embedded Unit Testing with Embassy

At this point, it may come as no surprise that the standard `#[test]` framework presented by Rust/Cargo is insufficient for our needs. The classic Rust test framework is great for standard non-async unit tests. But as we already know the systems we want to test are async. We've already refactored our code to be compatible with differing thread/mutex handling, so what now?

#### When enough isn't enough

There are several obstacles against us as we try to implement tests in the classic way if we want our code to:
1. Be async compatible
2. Be testable in both desktop and embedded contexts
3. Be transferable to testing on an embedded context without further refactoring

Normal test functions do not have an async entry point, so calling upon async methods becomes problematic at the least.

Tests are assumed to execute in their own thread and succeed when completing that thread.

To maintain consistency with the way we execute our methods in general, we choose to employ Embassy `Executor` here again. This makes sense because it is the same mechanisims by which our `main()` tasks have been dispatched.  

But a test framework assumes the system under test -- in this case what we do in `executor.run()` -- will exit cleanly when completed. But Embassy `executor.run()` is designed to be non-returning function and there is no way to break its loop.  The only remedy is to exit the process altogether, which is kind of a nuclear option but it does signal to the test framework that tests are complete for this unit.

There are async test harnesses -- our former friend `tokio` comes to mind -- but this is incompatible with the ultimate goal of having our tests be executable in an embedded target, and comes with refactoring ramifications of its own besides.

So we have created a sort of _compatible async test framework_ pattern that deviates from the standard in order to address these shortcomings.

This pattern gives us a way to execute asynchronous tests in a form that mirrors our runtime execution model, while still remaining compatible with the `cargo test` harness.

In the next section, we’ll demonstrate this test pattern in action by validating two key `SmartBattery` methods — `voltage()` and `current()` — and then proceed to verify the rest of the initial state.





