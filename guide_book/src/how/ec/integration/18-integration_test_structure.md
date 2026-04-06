# Integration Test Structure

Let's imagine a framework where we can set our expectations for our integration behavior over time or between states, then set the integration into motion where these expectations are tested, and get a report on what has passed and failed.  We can repeat different sets of such tests until we are satisfied we have tested everything we want to.

Such a framework would include a 

- a `TestReporter` that
    - tracks the start and end of a testing period, checking to see if the period is complete
    - records the evaluations that are to occur for this time period, and marks them as pass of fail
    - reports the outcomes of these tests

- a `Test entry` function that puts all of this into motion and defines the tests for each section and the scope of the tests.

## Components of the TestReporter

- TestResult enum
- Test structure, name, result, message
- evaluation trait
- assert helpers
- collection of Tests

Let's create `test_reporter.rs` and give it this content:
```rust
// test_reporter.rs

use std::fmt::{Display, Formatter};
use std::time::Instant;

/// Result of an evaluation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TestResult {
    Pending,
    Pass,
    Fail,
}
impl Default for TestResult {
    fn default() -> Self {
        Self::Pending
    }
}
impl Display for TestResult {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            TestResult::Pending => write!(f, "PENDING"),
            TestResult::Pass => write!(f, "PASS"),
            TestResult::Fail => write!(f, "FAIL"),
        }
    }
}

/// Per-test outcome produced by running an Evaluator.
#[derive(Debug, Clone)]
pub struct TestEval {
    pub name: &'static str,
    pub result: TestResult,
    pub message: Option<String>,
    // pub elapsed: Option<Duration>,
}
impl TestEval {
    pub fn new(name: &'static str) -> Self {
        Self { name, result: TestResult::Pending, message: None}
    }
}

/// Pass to mark pass/fail and attach messages.
#[derive(Debug, Default)]
pub struct TestObserver {
    result: TestResult,
    message: Option<String>,
}
#[allow(unused)]
impl TestObserver {
    // assume a test with no failures is considered passing.
    pub fn new() -> Self { Self { result: TestResult::Pass, message: None } }
    pub fn pass(&mut self) { self.result = TestResult::Pass; }
    pub fn fail(&mut self, reason: impl Into<String>) {
        self.result = TestResult::Fail;
        self.message = Some(reason.into());
    }
    pub fn result(&self) -> TestResult { self.result }
    pub fn message(&self) -> Option<&str> { self.message.as_deref() }
}

/// Trait each test implements. `run` should set PASS/FAIL on the observer.
pub trait Evaluator: Send {
    fn name(&self) -> &'static str;
    fn run(&mut self, obs: &mut TestObserver);
}

/// Helper: wrap a closure as an Evaluator.
pub struct FnEval {
    name: &'static str,
    f: Box<dyn FnMut(&mut TestObserver) + Send>,
}
impl FnEval {
    pub fn new(name: &'static str, f: impl FnMut(&mut TestObserver) + Send + 'static) -> Self {
        Self { name, f: Box::new(f) }
    }
}
impl Evaluator for FnEval {
    fn name(&self) -> &'static str { self.name }
    fn run(&mut self, obs: &mut TestObserver) { (self.f)(obs) }
}

/// A collection of tests plus section timing/reporting.
pub struct TestReporter {
    tests: Vec<Box<dyn Evaluator>>,
    results: Vec<TestEval>,
    section_start: Option<Instant>,
    section_end: Option<Instant>,
}
#[allow(unused)]
impl TestReporter {
    pub fn new() -> Self {
        Self { tests: Vec::new(), results: Vec::new(), section_start: None, section_end: None }
    }

    /// Register any Evaluator.
    pub fn add_test<E: Evaluator + 'static>(&mut self, eval: E) {
        self.tests.push(Box::new(eval));
    }

    /// Convenience: register inline closures.
    pub fn add_inline(&mut self, name: &'static str, f: impl FnMut(&mut TestObserver) + Send + 'static) {
        self.add_test(FnEval::new(name, f));
    }

    /// Begin a new section: clears previous results but keeps registered tests
    /// (so you can re-run same suite against evolving state). Call `clear_tests()`
    /// if you want to rebuild the suite per section.
    pub fn start_test_section(&mut self) {
        self.results.clear();
        self.section_start = Some(Instant::now());
        self.section_end = None;
    }

    /// Optionally rebuild the suite.
    pub fn clear_tests(&mut self) {
        self.tests.clear();
        self.results.clear();
    }

    /// Execute tests and capture results.
    pub fn evaluate_tests(&mut self) {
        self.results.clear();

        for t in self.tests.iter_mut() {
            let mut obs = TestObserver::new();
            let t_start = Instant::now();
            t.run(&mut obs);
            // let elapsed = t_start.elapsed();

            let result = obs.result;

            let mut ev = TestEval::new(t.name());
            ev.result = result;
            ev.message = obs.message().map(|s| s.to_string());
            // ev.elapsed = Some(elapsed);
            self.results.push(ev);
        }
    }

    /// End the section and print/report.
    /// returns 0 on success or -1 on failures, which can be used as a reported error code for exit
    pub fn end_test_section(&mut self) -> i32 {
        self.section_end = Some(Instant::now());
        self.print_report()
    }

    /// Aggregate and emit a summary report. Replace with your display backend as needed.
    /// returns 0 on success or -1 on failures, which can be used as a reported error code for exit
    pub fn print_report(&self) -> i32 {
        let total = self.results.len();
        let passed = self.results.iter().filter(|r| r.result == TestResult::Pass).count();
        let failed = self.results.iter().filter(|r| r.result == TestResult::Fail).count();

        let sec_elapsed = self.section_start
            .zip(self.section_end)
            .map(|(s, e)| e.duration_since(s));

        println!("==================================================");
        println!(" Test Section Report");
        if let Some(d) = sec_elapsed {
            println!(" Duration: {:?}\n", d);
        }

        for r in &self.results {
            // let time = r.elapsed.map(|d| format!("{:?}", d)).unwrap_or_else(|| "-".into());
            match (&r.result, &r.message) {
                (TestResult::Pass, _) => {
                    println!("[PASS] {:<40}", r.name);
                }
                (TestResult::Fail, Some(msg)) => {
                    println!("[FAIL] {:<40} — {}", r.name, msg);
                }
                (TestResult::Fail, None) => {
                    println!("[FAIL] {:<40}", r.name);
                }
                (TestResult::Pending, _) => {
                    println!("[PEND] {:<40}", r.name);
                }
            }
        }
        println!("\n Summary: total={}, passed={}, failed={}", total, passed, failed);
        println!("==================================================");
        
        // return error code 0 == success, -1 == failure
        if total == passed { 0 } else { -1 } 
    }

    /// Retrieve results programmatically (e.g., to feed a UI).
    pub fn results(&self) -> &[TestEval] { &self.results }
}

// Simple assertion macros

/// Test a boolean expression
/// Usage: expect!(obs, is_true, _optional_message);
#[macro_export]
macro_rules! expect {
    ($obs:expr, $cond:expr, $($msg:tt)*) => {{
        if !($cond) {
            $obs.fail(format!($($msg)*));
            return;
        }
    }};
}

/// Compare two values for equality
/// Usage: expect_eq!(obs, actual, expected, _optional_message);
#[macro_export]
macro_rules! expect_eq {
    ($obs:expr, $left:expr, $right:expr $(, $($msg:tt)*)? ) => {{
        if $left != $right {
            let msg = format!(
                concat!("expected == actual, but got:\n  expected: {:?}\n  actual:   {:?}", $(concat!("\n  ", $($msg)*))?),
                &$right, &$left
            );
            $obs.fail(msg);
            return;
        }
    }};
}

/// Compare two numbers after rounding to `places` decimal places.
/// Usage: expect_to_decimal!(obs, actual, expected, places);
#[macro_export]
macro_rules! expect_to_decimal {
    ($obs:expr, $actual:expr, $expected:expr, $places:expr $(,)?) => {{
        // Work in f64 for better rounding behavior, then compare the rounded integers.
        let a_f64: f64 = ($actual) as f64;
        let e_f64: f64 = ($expected) as f64;
        let places_u: usize = ($places) as usize;
        let scale: f64 = 10f64.powi(places_u as i32);

        let a_round_i = (a_f64 * scale).round() as i64;
        let e_round_i = (e_f64 * scale).round() as i64;

        if a_round_i == e_round_i {
            $obs.pass();
        } else {
            // Nice message with the same precision the comparison used
            let a_round = a_round_i as f64 / scale;
            let e_round = e_round_i as f64 / scale;

            let msg = format!(
                "expected ~= {e:.prec$} but got {a:.prec$} (rounded to {places} dp; {e_round:.prec$} vs {a_round:.prec$})",
                e = e_f64,
                a = a_f64,
                e_round = e_round,
                a_round = a_round,
                prec = places_u,
                places = places_u
            );
            $obs.fail(&msg);
        }
    }};
}

/// Syntactic sugar to add inline tests:
/// add_test!(reporter, "Name", |obs| { /* ... */ });
#[macro_export]
macro_rules! add_test {
    ($reporter:expr, $name:expr, |$obs:ident| $body:block) => {{
        $reporter.add_inline($name, move |$obs: &mut TestObserver| $body);
    }};
}
```
This establishes the feature framework we discussed above. It is able to collect and report on test evaluations for one or many test sections, and provides some helpful macros such as `add_test!` to register a closure as the evaluation function as well as some assertion macros designed to use with the `TestObserver`.

Add this as a module also to `main.rs`:
```rust
mod test_reporter;
```

## Wiring it into the IntegrationTest DisplayRenderer
Central to our plan is the idea that we can make a `DisplayRenderer` variant that will feed us the results of the simulation as it runs.  We can then evaluate these values in context and assign Pass/Fail results to the `TestReporter` and print out the final tally.

To do this, we need to "tap" the `render_static` and `render_frame` traits of our `IntegrationTestBackend` and feed this data into where we are running the test code.

### Adding the TestTap

Let's replace our placeholder `integration_test_render.rs` file with this new version:
```rust

use crate::display_render::display_render::{RendererBackend};
use crate::display_models::{StaticValues,DisplayValues, InteractionValues};
use ec_common::mutex::{Mutex, RawMutex};

pub trait TestTap: Send + 'static {
    fn on_static(&mut self, sv: &StaticValues);
    fn on_frame(&mut self, dv: &DisplayValues);
}

struct NullTap;
#[allow(unused)]
impl TestTap for NullTap {
    fn on_static(&mut self, _sv: &StaticValues) {}
    fn on_frame(&mut self, _dv: &DisplayValues) {}
}

pub struct IntegrationTestBackend {
    tap: Mutex<RawMutex, Box<dyn TestTap + Send>>
}
impl IntegrationTestBackend { 
    pub fn new() -> Self { 
        Self {
            tap: Mutex::new(Box::new(NullTap))
        } 
    }
} 
impl RendererBackend for IntegrationTestBackend {
    fn render_frame(&mut self, dv: &DisplayValues, _ia: &InteractionValues) {
        let mut t = self.tap.try_lock().expect("tap locked in another task?");
        t.on_frame(dv);
    }
    fn render_static(&mut self, sv: &StaticValues) {
        let mut t = self.tap.try_lock().expect("tap locked in another task?");
        t.on_static(sv);
    }
    #[cfg(feature = "integration-test")]
    fn set_test_tap(&mut self, tap: Box<dyn TestTap + Send>) {
        let mut guard = self.tap.try_lock().expect("tap locked in another task?");
        *guard = tap;
    }}
```

You will see that we have defined a `TestTap` trait that provides us with the callback methods we are looking for to feed our test running code.  We've given a concrete implementation `NullTap` to use as a no-op stub to hold fort until we replace it with `set_test_tap()` later.  

We will need to make some changes to our `display_render.rs` file to accommodate this.  Open up that file and add the following:

```rust
use crate::display_render::integration_test_render::IntegrationTestBackend;
#[cfg(feature = "integration-test")]
use crate::display_render::integration_test_render::TestTap;

```

Change the trait definition for `RendererBackend` to now be:
```rust
// Define a trait for the interface for a rendering backend
pub trait RendererBackend : Send + Sync {
    fn on_enter(&mut self, _last: Option<&DisplayValues>) {}
    fn on_exit(&mut self) {}
    fn render_frame(&mut self, dv: &DisplayValues, ia: &InteractionValues);
    fn render_static(&mut self, sv: &StaticValues);
    #[cfg(feature = "integration-test")]
    fn set_test_tap(&mut self, _tap: Box<dyn TestTap + Send>) {}
}
```

This gives us the ability to set the test tap, and it defaults to nothing unless we implement it, as we have done already in `integration_test_render.rs`.

Now add this function to the `impl DisplayRender` block:
```rust
    #[cfg(feature = "integration-test")]
    pub fn set_test_tap<T>(&mut self, tap: T) -> Result<(), &'static str>
    where
        T: TestTap + Send + 'static,
    {
        if self.mode != RenderMode::IntegrationTest {
            return Err("Renderer is not in Integration Test mode");
        }
        self.backend.set_test_tap(Box::new(tap));
        Ok(())
    }
```

### Using these changes in test code

Now we can start to build in the test code itself.

We'll create a new file for this: `integration_test.rs` and give it this content:
```rust
#[cfg(feature = "integration-test")]
pub mod test_module {

    use crate::test_reporter::test_reporter::TestObserver;
    use crate::test_reporter::test_reporter::TestReporter;
    use crate::{add_test,expect, expect_eq};
    use crate::display_models::{DisplayValues, StaticValues};
    use crate::display_render::integration_test_render::TestTap;
    use crate::entry::DisplayChannelWrapper;
    use crate::display_render::display_render::DisplayRenderer;
    use crate::events::RenderMode;

    #[embassy_executor::task]
    pub async fn integration_test(rx: &'static DisplayChannelWrapper) {

        let mut reporter = TestReporter::new();
        
        reporter.start_test_section();


        struct ITest {
            reporter: TestReporter,
            first_time: Option<u64>,
            test_time_ms: u64,
            saw_static: bool,
            frame_count: i16
        }
        impl ITest {
            pub fn new() -> Self {
                Self {
                    reporter: TestReporter::new(),
                    first_time: None,
                    test_time_ms: 0,
                    saw_static: false,
                    frame_count: 0
                }
            }
        }
        impl TestTap for ITest {
            fn on_static(&mut self, sv: &StaticValues) {
                add_test!(self.reporter, "Static Values received", |obs| {
                    obs.pass(); 
                });
                self.saw_static = true;
                println!("🔬 Integration testing starting...");
            }
            fn on_frame(&mut self, dv: &DisplayValues) {
                let load_ma= dv.load_ma; 
                let first = self.first_time.get_or_insert(dv.sim_time_ms as u64);
                self.test_time_ms = (dv.sim_time_ms as u64).saturating_sub(*first);

                if self.frame_count == 0 {
                    // ⬇️ Take snapshots so the closure doesn't capture `self`
                    let saw_static_snapshot = self.saw_static;
                    let load_at_start = load_ma;
                    let expected = 1200;

                    add_test!(self.reporter, "First Test Data Frame received", |obs| {
                        expect!(obs, saw_static_snapshot, "Static Data should have come first");
                        expect_eq!(obs, load_at_start, expected, "Load value at start");
                        obs.pass();
                    });
                }

                self.frame_count += 1;

                if self.test_time_ms > 5_000 {
                    // `self` is fine to use here; the borrow from add_test! ended at the call.
                    self.reporter.evaluate_tests();
                    self.reporter.print_report();
                    std::process::exit(0);
                }
            }
        }
        let mut r = DisplayRenderer::new(RenderMode::IntegrationTest);
        r.set_test_tap(ITest::new()).unwrap();
        r.run(rx).await;

    }
}
```
Note that we've wrapped this entire file content as a module and gated it behind `#[cfg(feature = "integration-test")]` so that it is only valid in integration-test mode.  

add this module to `main.rs`
```rust
mod integration_test;
```

and in `entry.rs`, add the import for this task:
```rust
#[cfg(feature = "integration-test")]
use crate::integration_test::test_module::integration_test;
```

also in `entry.rs`, replace the spawn of `render_task` with the spawn to `integration_test`, passing the display channel that will continue to be used for our tapped Display messaging which will now route to our test code.
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

    spawner.spawn(integration_test(shared.display_channel)).unwrap();
}
```

A `cargo run --features integration-test` should produce the following output:
```
     Running `C:\Users\StevenOhmert\odp\ec_examples\target\debug\integration_project.exe`
🚀 Integration test mode: integration project
setup_and_tap_starting
⚙️ Initializing embedded-services
⚙️ Spawning battery service task
⚙️ Spawning battery wrapper task
🧩 Registering battery device...
🧩 Registering charger device...
🧩 Registering sensor device...
🧩 Registering fan device...
🔌 Initializing battery fuel gauge service...
Setup and Tap calling ControllerCore::start...
In ControllerCore::start()
spawning controller_core_task
spawning start_charger_task
spawning charger_policy_event_task
spawning integration_listener_task
init complete
🥺 Doing battery service startup -- DoInit followed by PollDynamicData
✅ Charger is ready.
🥳 >>>>> ping has been called!!! <<<<<<
🛠️  Charger initialized.
battery-service DoInit -> Ok(Ack)
🔬 Integration testing starting...
==================================================
 Test Section Report
[PASS] Static Values received                   (1µs)
[PASS] First Test Data Frame received           (400ns)

 Summary: total=2, passed=2, failed=0
==================================================
```

That's a good proof-of-concept start.  Let's create some meaningful tests now.







