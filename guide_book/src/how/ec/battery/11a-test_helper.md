# Test Helper

Because the normal rust test framework lacks async support and because the Embassy `Executor` `run()` loop is designed to never exit, writing tests against our asynchronous trait methods presents a challenge and requires some extra framing.

>## Pros and cons of the Test Helper
>- ✅ Allows async code to be tested
>- ✅ Tests will run in an embedded context
>- ✅ Tests remain easily constructed
>- ✅ Test failures are reported clearly
>- ❌ All async test tasks are treated as a single test
>- ❌ System under test process is forcibly ended when tests complete
>- ❌ No direct acknowledgement of test success is reported, although failures are still reported.
>- ❌ Not a standardized approach


Create a file named `test_helper.rs` in the project with this content:
```rust
// test_helper.rs

#[allow(unused_imports)]
use embassy_executor::{Executor, Spawner};
#[allow(unused_imports)]
use embassy_sync::signal::Signal;
#[allow(unused_imports)]
use static_cell::StaticCell;
#[allow(unused_imports)]
use crate::mutex::RawMutex; 

/// Helper macro to exit the process when all signals complete.
#[macro_export]
macro_rules! finish_test {
    () => {
        std::process::exit(0)
    };
}

/// Spawn a task that waits for all provided signals to fire, then exits.
#[cfg(test)]
pub fn join_signals<const N: usize>(
    spawner: &Spawner,
    signals: [&'static Signal<RawMutex, ()>; N],
) {
    let leaked: &'static [&'static Signal<RawMutex, ()>] = Box::leak(Box::new(signals));
    spawner.must_spawn(test_end(leaked));
}

/// Async task that waits for all signals to complete.
#[embassy_executor::task]
async fn test_end(signals: &'static [&'static Signal<RawMutex, ()>]) {
    for sig in signals.iter() {
        sig.wait().await;
    }
    finish_test!();
}
```
This helper still requires us to set up some additional rigging when we define our test and the async tasks we will be testing, but it simplifies the signaling required so that the tests can announce when they are complete before exiting the test run.

add this to your lib.rs file also:
```rust
pub mod mock_battery;
pub mod virtual_battery;
pub mod mock_battery_device;
pub mod espi_service;
pub mod mock_battery_controller;
pub mod types;
pub mod mutex;
pub mod test_helper;
```

Next we will create our first unit tests using this.


