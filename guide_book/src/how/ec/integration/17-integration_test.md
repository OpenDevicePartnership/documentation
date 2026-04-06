# Integration Test
At long last, we are at the integration test portion of this exercise -- along the way, we have created an integration that we can empirically run and evaluate, but a true integration test is automated, repeatable, and ideally part of a continuous integration (CI) process.  We will create a test that runs the simulation for a short period of time, exercising the various components and their interactions, and then we will evaluate the results to ensure that they are as expected.

A true integration test is invaluable in an environment where components are being actively developed, as it provides a way to ensure that changes in one component do not inadvertently break the overall system.  It also provides a way to validate that the system as a whole is functioning as intended, and that the various components are interacting correctly.  

When things do begin to differ, one can use the interactive modes of an application such as this one to explore and understand the differences, and then make adjustments as needed.

### Back to the DisplayRenderer
Our latest revision in the exercise was to create an in-place renderer that provides a more interactive experience.  We can use the same mechanism to "render" to a testing construct that collects the results of simulated situations, evaluates them, and reports the results.

This is similar to the Test Observer pattern used in previous examples, although adapted here for this new context.

## Feature selection
We don't want our test mode "display" to be one of the toggle options of our simulation app.  Rather, we want this to be selected at the start when we run the app in "integration-test" mode.  So let's define some feature flags that will define our starting modes:

So, before we even start defining our integration test support, let's posit that this will be a separately selectable compile and runtime mode that we want to designate with a `--features` flag.

Our `Cargo.toml` already defines a `[features]` section that was mostly inherited from previous integration examples, and establishes the thread mode to use in different contexts.
We will keep that part of things intact so as not to interfere with the behavior of our dependent crates,
but we will extend it to introduce modes for `log-mode`, `in-place-mode` and `integration-test` mode, with `in-place-mode` being the default if no feature selection is made explicitly.

In `Cargo.toml`
```toml
[features] 
default = ["in-place-mode"]
integration-test = ["std", "thread-mode"]
log-mode = ["std", "thread-mode"]
in-place-mode = ["std", "thread-mode"]
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
Then, in `main.rs` we can use this to choose which of our starting tasks we wish to launch:
```rust
#[embassy_executor::main]
async fn main(spawner: Spawner) { 

    #[cfg(feature = "integration-test")]
        spawner.spawn(entry::entry_task_integration_test(spawner)).unwrap();

    #[cfg(not(feature = "integration-test"))]
        spawner.spawn(entry::entry_task_interactive(spawner)).unwrap();
}
```
This will set apart the integration test into a separate launch we will establish in `entry.rs` as well as 
further separating the selection of `RenderMode::Log` vs. `RenderMode::InPlace` as the default to start with when not in test mode.

In `entry.rs`, create the new entry task, and modify the render_task so that the `RenderMode` is passed in:
```rust
#[cfg(feature = "integration-test")]
#[embassy_executor::task]
pub async fn entry_task_integration_test(spawner: Spawner) {
    println!("🚀 Integration test mode: integration project");
    let shared = init_shared();
 
    println!("setup_and_tap_starting");
    let battery_ready = shared.battery_ready;
    spawner.spawn(setup_and_tap_task(spawner, shared)).unwrap();
    battery_ready.wait().await;
    println!("init complete");

    spawner.spawn(render_task(shared.display_channel, RenderMode::IntegrationTest)).unwrap();
}

#[embassy_executor::task]
pub async fn render_task(rx: &'static DisplayChannelWrapper, mode:RenderMode) {
    let mut r = DisplayRenderer::new(mode);
    r.run(rx).await;
}
```
Then, let's modify `entry_task_interactive` to respect the feature options for starting `RenderMode` as well:
```rust
#[embassy_executor::task]
pub async fn entry_task_interactive(spawner: Spawner) {
    println!("🚀 Interactive mode: integration project");
    let shared = init_shared();
 
    println!("setup_and_tap_starting");
    let battery_ready = shared.battery_ready;
    spawner.spawn(setup_and_tap_task(spawner, shared)).unwrap();
    battery_ready.wait().await;
    println!("init complete");

    spawner.spawn(interaction_task(shared.interaction_channel)).unwrap();
    
    #[cfg(feature = "log-mode")]
    let mode = RenderMode::Log;
    #[cfg(not(feature = "log-mode"))]
    #[cfg(feature = "in-place-mode")]
    let mode = RenderMode::InPlace;

    spawner.spawn(render_task(shared.display_channel, mode)).unwrap();
}
```

### RenderMode::IntegrationTest

We need to add the integration test mode to our `RenderMode` enum, and we need to create a placeholder for the rendering backend it will represent.

In `events.rs`, modify the `RenderMode` enum to now be:
```rust
pub enum RenderMode {
    InPlace,                // ANSI Terminal application
    Log,                    // line-based console output
    IntegrationTest         // Collector/Reporter for testing
}
```

Then create a new file in the `display_render` folder named `integration_test_render.rs` and give it this placeholder content for now:
```rust

use crate::display_render::display_render::{RendererBackend};
use crate::display_models::{StaticValues,DisplayValues, InteractionValues};

pub struct IntegrationTestBackend;
impl IntegrationTestBackend { pub fn new() -> Self { Self } }
impl RendererBackend for IntegrationTestBackend {
    fn render_frame(&mut self, _dv: &DisplayValues, _ia: &InteractionValues) {
    }
    fn render_static(&mut self, _sv: &StaticValues) {
    }
}
```
this won't actually do anything more yet other than satisfy our traits for a valid backend renderer.

we need to add this also to `display_render/mod.rs`:
```
// display_render
pub mod display_render;
pub mod log_render;
pub mod in_place_render;
pub mod integration_test_render;
```

In `display_render.rs`, we can import this:
```rust
use crate::display_render::integration_test_render::IntegrationTestBackend;
```

and add it to the `match` statement of `make_backend()`:
```rust
    fn make_backend(mode: RenderMode) -> Box<dyn RendererBackend> {
        match mode {
            RenderMode::InPlace => Box::new(InPlaceBackend::new()),
            RenderMode::Log => Box::new(LogBackend::new()),
            RenderMode::IntegrationTest => Box::new(IntegrationTestBackend::new())
        }
    }
```

now, we should be able to run in different modes from feature flags:

```
cargo run --features in-place-mode
```
or simply
```
cargo run
```
should give us our ANSI "In Place" app-style rendering.
```
cargo run --features log-mode
```
should give us our log mode output from the start.
```
cargo run --features integration-test
```
should not emit anything past the initial `println!` statements up through `DoInit`, since we have a non-functional rendering implementation in place here.

Next, let's explore how we want to conduct our integration tests.



