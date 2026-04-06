# Adding Meaningful Tests

We have the ability to run the app as an interactive simulation, including the logging mode that will output a running record of the changes over time as we change the load.

So, it makes sense to derive some sense of expected behavior from these results and model tests that correspond to this.  

## What are we really testing?

Of course, this is a simulated integration of virtual components -- running simulation algorithms as stand-ins for actual physical behaviors -- so when we run our tests, we are also testing the realism of these sims.  Although reasonable effort has been made to account for the physics of temperature change, battery life, and so on, it should not be expected that these are precisely accurate.  In a real integration, you don't get to change the effects of physics -- so we'll test against the physical reality as it is presented to us, realistic or otherwise.

Running with the default configurations as we have built them in this example, we can observe the battery starts off at 100% SOC and we have a starting default system load/draw of 9.4W.  The battery thus discharges to a point where the charger activates below 90%, then charges back up to 100%, detaches the charger, and the cycle repeats.

If we increase the load during any of this, the battery discharges faster, and the temperature rises more quickly and at the configured point of 28 degrees celsius, the fan turns on to facilitate cooling.  The ability of the fan to counter the load depends upon the continued draw level, and whether or not the charger is running.  If cooling is sufficient, the fan slows, and under lower load, will turn off.

As we've written it, the test context does not have the ability to change the simulated time multiplier the way the interactive context allows, so all simulation time for the test runs at the pre-configured level 3 (25X).  

### Running faster
Since this is a test, we don't need to dally.  Let's make a change so that the default level for the integration-test mode is level 5 (100X).  In `controller_core.rs` add the following lines at the top of the `controller_core_task` so that this executes once at the start before entering the event loop:
```rust
    #[cfg(feature = "integration-test")]
    {
        let core = core_mutex.lock().await;
        core.sysobs.set_speed_number(5).await;
    }

```

## Checking static, then stepwise events

Our initial tests already establish that static data is received, and verifies the one-time-at-the-start behavior is respected, but we don't check any values.  This is largely superfluous, of course, but we should verify anyway.

Following this first event, we need a good way to know where we are at in the flow of subsequent events so that we can properly evaluate and direct the context at the time.

Let's update our current `integration_test.rs` code with a somewhat revised version:
```rust
#[cfg(feature = "integration-test")]
pub mod integration_test {
    use crate::test_reporter::test_reporter::TestObserver;
    use crate::test_reporter::test_reporter::TestReporter;
    use crate::{add_test,expect, expect_eq};
    use crate::display_models::{DisplayValues, StaticValues};
    use crate::display_render::integration_test_render::TestTap;
    use crate::entry::DisplayChannelWrapper;
    use crate::display_render::display_render::DisplayRenderer;
    use crate::events::RenderMode;

    #[allow(unused)]
    #[derive(Debug)]
    enum TestStep {
        None,
        CheckStartingValues,
        CheckChargerAttach,
        RaiseLoadAndCheckTemp,
        RaiseLoadAndCheckFan,
        LowerLoadAndCheckCooling,
        EndAndReport
    }

    #[embassy_executor::task]
    pub async fn integration_test(rx: &'static DisplayChannelWrapper) {

        struct ITest {
            reporter: TestReporter,
            first_time: Option<u64>,
            test_time_ms: u64,
            saw_static: bool,
            frame_count: i16,
            step: TestStep,
        }
        impl ITest {
            pub fn new() -> Self {
                let mut reporter = TestReporter::new();
                reporter.start_test_section(); // start out with a new section
                Self {
                    reporter,
                    first_time: None,
                    test_time_ms: 0,
                    saw_static: false,
                    frame_count: 0,
                    step: TestStep::None
                }
            }

            // -- Individual step tests ---

            fn check_starting_values(&mut self, draw_watts:f32) -> TestStep {
                let reporter = &mut self.reporter;
                add_test!(reporter, "Check Starting Values", |obs| {
                    expect_eq!(obs, draw_watts, 9.4);
                    obs.pass();
                });
                TestStep::EndAndReport
            }

            // --- final step to report and exit --
            fn end_and_report(&mut self) {
                let reporter = &mut self.reporter;
                reporter.evaluate_tests();
                reporter.end_test_section();
                std::process::exit(0);
            }
        }
        impl TestTap for ITest {
            fn on_static(&mut self, sv: &StaticValues) {
                let _ = sv;
                add_test!(self.reporter, "Static Values received", |obs| {
                    obs.pass(); 
                });
                self.saw_static = true;
                println!("🔬 Integration testing starting...");
            }
            fn on_frame(&mut self, dv: &DisplayValues) {

                let reporter = &mut self.reporter;
                let first = self.first_time.get_or_insert(dv.sim_time_ms as u64);
                self.test_time_ms = (dv.sim_time_ms as u64).saturating_sub(*first);

                if self.frame_count == 0 {
                    // Take snapshots so the closure doesn't capture `self`
                    let saw_static = self.saw_static;

                    add_test!(reporter, "First Test Data Frame received", |obs| {
                        expect!(obs, saw_static, "Static Data should have come first");
                        obs.pass();
                    });
                    self.step = TestStep::CheckStartingValues;
                }
                println!("Step {:?}", self.step);
                match self.step  {
                    TestStep::CheckStartingValues => {
                        let draw_watts = dv.draw_watts;
                        self.step = self.check_starting_values(draw_watts);
                    },
                    TestStep::EndAndReport => self.end_and_report(),
                    _ => {}
                }

                self.frame_count += 1;

            }
        }
        let mut r = DisplayRenderer::new(RenderMode::IntegrationTest);
        r.set_test_tap(ITest::new()).unwrap();
        r.run(rx).await;

    }
}
```
This introduces a few notable changes.

We've introduced an enum, `TestStep`, that names a series of proposed points in the flow that we wish to make measurements. For now, we are only using the first of these `CheckStartingValues`, but the pattern will remain the same for any subsequent steps.  We have a corresponding `check_starting_values` method defined that conducts the actual test.  Note the `end_and_report` method also, which is the last step of the flow and signals it is time to report the test results and exit.

This revised version does little more just yet than our previous one, but it sets the stage for stepwise updates.
`cargo run --features integration-test`:
```
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
Step CheckStartingValues
Step EndAndReport
==================================================
 Test Section Report
[PASS] Static Values received                   (700ns)
[PASS] First Test Data Frame received           (400ns)
[PASS] Check Starting Values                    (300ns)

 Summary: total=3, passed=3, failed=0
==================================================
```
Before we move on with the next steps, let's finish out the perfunctory tasks of verifying our static data and a couple more starting values:

Replace the current `on_static` method with this one:
```rust
            fn on_static(&mut self, sv: &StaticValues) {
                let reporter = &mut self.reporter;
                let mfg_name = sv.battery_mfr.clone();
                let dev_name = sv.battery_name.clone();
                let chem = sv.battery_chem.clone();
                let cap_mwh = sv.battery_dsgn_cap_mwh;
                let cap_mv = sv.battery_dsgn_voltage_mv;
                add_test!(reporter, "Static Values received", |obs| {
                    expect_eq!(obs, mfg_name.trim_end_matches('\0'), "MockBatteryCorp");
                    expect_eq!(obs, dev_name.trim_end_matches('\0'), "MB-4200");
                    expect_eq!(obs, chem.trim_end_matches('\0'), "LION");
                    expect_eq!(obs, cap_mwh, 5000);
                    expect_eq!(obs, cap_mv, 7800);
                });
                self.saw_static = true;
                println!("🔬 Integration testing starting...");
            }
```
and we'll check some more of the starting values.  Change the member function `check_starting_values()` to this version:
```rust
            fn check_starting_values(&mut self, soc:f32, draw_watts:f32, charge_watts:f32, temp_c:f32, fan_rpm:u16) -> TestStep {
                let reporter = &mut self.reporter;
                add_test!(reporter, "Check Starting Values", |obs| {
                    expect_eq!(obs, soc, 100.0);
                    expect_eq!(obs, draw_watts, 9.4);
                    expect_eq!(obs, charge_watts, 0.0);
                    expect_to_decimal!(obs, temp_c, 24.6, 1);
                    expect_eq!(obs, fan_rpm, 0);
                });
                //TestStep::CheckChargerAttach
                TestStep::EndAndReport
            }
```
and change the match arm to call it like this:
```rust
                    TestStep::CheckStartingValues => {
                        let draw_watts = dv.draw_watts;
                        let charge_watts = dv.charge_watts;
                        let temp_c = dv.temp_c;
                        let soc = dv.soc_percent;
                        let fan_rpm = dv.fan_rpm;

                        self.step = self.check_starting_values(soc, draw_watts, charge_watts, temp_c, fan_rpm);
                    },
```
Now we can be reasonably confident that we are starting out as expected before continuing.


> ### A note on test value measurements
> In our starting values test we check the starting temperature pretty closely (to within 1 decimal position),
> but in other tests we look for a more general threshold of range.  
> In the case of starting values, we know what this should be because it comes from the scenario configurations, and 
> we can be confident in the deterministic outcome.
> In other examples, we can't be entirely sure of the vagaries of time -- even in a simulation, what with differing host computer speeds, drifts in clocks, and inevitable inaccuracies in our simulated physics.  So we "loosen the belt" a bit more in these situations.
>
> ----








