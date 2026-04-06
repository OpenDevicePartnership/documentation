# Affecting Change in the tests

For our next test, we want to raise the system load and then see how that affects temperature (it should rise).

We don't currently have a way to tell the simulation to raise the load.  But in interactive mode we can, and we did that by sending `InteractionEvent` messages.  Let's do that here.  We'll need to pass in the `InteractionChannelWrapper` we need for sending these messages into the `integration_test()` function.

Start by adding these imports:
```rust
    use crate::entry::InteractionChannelWrapper;
    use ec_common::espi_service::EventChannel;
    use crate::events::InteractionEvent;
```
Then, change the signature for `interaction_test()` to accept the new parameter:
```rust
    #[embassy_executor::task]
    pub async fn integration_test(rx: &'static DisplayChannelWrapper, tx:&'static InteractionChannelWrapper) {
```
Now, unlike the `rx` parameter that we use within the body of the function, we need this `tx` parameter available to us while we are in the test code -- and therefore the `ITest` structure itself, so we need to add it as a member and pass it in on the constructor:

```rust
        struct ITest {
            reporter: TestReporter,
            tx: &'static InteractionChannelWrapper,
            ...
        }
```
and
```rust
        impl ITest {
            pub fn new(tx:&'static InteractionChannelWrapper) -> Self {
                let mut reporter = TestReporter::new();
                reporter.start_test_section(); // start out with a new section
                Self {
                    reporter,
                    tx,
                    ...
```
and pass `tx` in the `ITest` constructor in this code at the bottom of the `integration_test()` function:
```rust
        let mut r = DisplayRenderer::new(RenderMode::IntegrationTest);
        r.set_test_tap(ITest::new(tx)).unwrap();
        r.run(rx).await;
```

Note that the `rx` (Display) Channel is consumed entirely within the `DisplayRenderer` `run` loop, whereas our `tx` (Interaction) Channel must be available to us in `ITest` for ad-hoc sending of `InteractionEvent` messages within our test steps, thus the way we've bifurcated the usage of these here.

Now we are set up to call on interaction event to increase and decrease the load, as we will use in the next test.

Our `TestStep` enum for this is `RaiseLoadAndCheckTemp`.
Create a new member function to handle this:

```rust
fn raise_load_and_check_temp(&mut self, mins_passed:f32, draw_watts: f32, temp_c:f32) -> TestStep {
    let reporter = &mut self.reporter;

    TestStep::EndAndReport
}
```
We'll fill it out later. First, we need to add some helper members we can use to track time and temperature.

Add these members to the `ITest` struct:
```rust
            mark_time: Option<f32>,
            mark_temp: Option<f32>,
```
and initialize them as `None`:
```rust
                    mark_time: None,
                    mark_temp: None,
```
Now, fill out our `raise_load_and_check_temp` function to look like this:
```rust
            fn raise_load_and_check_temp(&mut self, mins_passed:f32, draw_watts: f32, temp_c:f32) -> TestStep {

                let reporter = &mut self.reporter;

                if self.mark_time == None {
                    self.mark_time = Some(mins_passed);
                    self.mark_temp = Some(temp_c);
                }
                
                if draw_watts < 20.0 { // raise to something above 20 then stop pumping it up
                    let _ = self.tx.try_send(InteractionEvent::LoadUp);
                    return TestStep::RaiseLoadAndCheckTemp                    
                }
                let mt = *self.mark_time.get_or_insert(mins_passed);
                let time_at_charge = if mins_passed > mt { mins_passed - mt } else { 0.0 };
                if time_at_charge > 0.5 { // after about 30 seconds, check temperature
                    let temp_raised = self.mark_temp.map_or(0.0, |mt| if temp_c > mt { temp_c - mt } else { 0.0 });
                    add_test!(reporter, "Temperature rises on charge", |obs| {
                        expect!(obs, temp_raised > 1.5, "Temp should rise noticeably"); 
                    });
                } else {
                    // keep going
                    return TestStep::RaiseLoadAndCheckTemp
                } 
                // reset in case we want to use these again later
                self.mark_temp = None;
                self.mark_time = None;
                // TestStep::RaiseLoadAndCheckFan   // next step             
                TestStep::EndAndReport
            }
```
What we do here is mark the time when we first get in, then we bump up the the load using our new `tx` member until we see that the load is something above 20w. At that point we check the time to see if at least 1/2 a minute has passed. Until these conditions are met, we keep returning `TestStep::RaiseLoadAndCheckTemp` to keep us evaluating this state. Once there, we check how high the temperature has risen since the last check, relative to the marked baseline.  We expect it to be around 2 degrees, give or take, so we'll check for 1.5 degrees or more as our test. We then go to the next step (for now, `EndAndReport`), but before we do we reset our `Option` marks in case we want to reuse them in subsequent tests.

Remember to change the return value of `check_charger_attach` to go to `TestStep::RaiseLoadAndCheckTemp` also, or this test won't fire.

Then add the calling code in the match arms section below:
```rust
                    TestStep::RaiseLoadAndCheckTemp => {
                        let mins_passed = dv.sim_time_ms / 60_000.0;
                        let load_watts = dv.draw_watts;
                        let temp_c = dv.temp_c;

                        self.step = self.raise_load_and_check_temp(mins_passed, load_watts, temp_c);
                    },
```

## Checking the Fan
The next test we'll create is similar, but in this case, we'll raise the load (and heat) significantly enough for the system fan to kick in.

Create the member function we'll need for this. it will look much like the previous one in many ways:
```rust
            fn raise_load_and_check_fan(&mut self, mins_passed:f32, draw_watts:f32, temp_c:f32, fan_rpm:u16) -> TestStep {
                let reporter = &mut self.reporter;

                // record time we started this
                if self.mark_time == None {
                    self.mark_time = Some(mins_passed);
                }
                
                if draw_watts < 39.0 { // raise to maximum
                    let _ = self.tx.try_send(InteractionEvent::LoadUp);
                    return TestStep::RaiseLoadAndCheckFan                    
                }
                let mt = *self.mark_time.get_or_insert(mins_passed);
                let time_elapsed = if mins_passed > mt { mins_passed - mt } else { 0.0 };
                if time_elapsed > 0.25 && fan_rpm == 0 { // this should happen relatively quickly
                    add_test!(reporter, "Timed out waiting for fan", |obs| {
                        obs.fail("Time expired");
                    });
                    return TestStep::EndAndReport  // quit tests if we timeout
                }
                
                if fan_rpm > 0 {
                    add_test!(reporter, "Temperature is warm", |obs| {
                        expect!(obs, temp_c >= 28.0, "temp below fan on range");
                    });                    
                    add_test!(reporter, "Fan turns on", |obs| {
                        obs.pass();
                    });
                } else {
                    // keep going
                    return TestStep::RaiseLoadAndCheckFan
                }
                // reset in case we want to use these again later
                self.mark_temp = None;
                self.mark_time = None;
                // TestStep::LowerLoadAndCheckCooling
                TestStep::EndAndReport
            }
```
add the calling case to the match arm:
```rust
                    TestStep::RaiseLoadAndCheckFan => {
                        let mins_passed = dv.sim_time_ms / 60_000.0;
                        let draw_watts = dv.draw_watts;
                        let temp_c = dv.temp_c;
                        let fan_rpm = dv.fan_rpm;

                        self.step = self.raise_load_and_check_fan(mins_passed, draw_watts, temp_c, fan_rpm);
                    },
```
Don't forget to update the next step return of the previous step so that it carries forward to this one.

## Time to Chill
Great! Now, let's make sure the temperature goes back down with less demand on the system and that the fan backs off when cooling is complete.

Create the member function
```rust
            fn lower_load_and_check_cooling(&mut self, mins_passed:f32, draw_watts:f32, temp_c:f32, fan_rpm:u16) -> TestStep {
                let reporter = &mut self.reporter;

                // record time and temp when we started this
                if self.mark_time == None {
                    self.mark_time = Some(mins_passed);
                    self.mark_temp = Some(temp_c);
                }
                
                // drop load back to low
                if draw_watts > 10.0 { 
                    let _ = self.tx.try_send(InteractionEvent::LoadDown);
                    return TestStep::LowerLoadAndCheckCooling                    
                }
                // wait a bit
                let mark_time = *self.mark_time.get_or_insert(mins_passed);
                let diff = mins_passed - mark_time;
                if diff < 60.0 { // wait for an hour for it to cool all the way 
                    return TestStep::LowerLoadAndCheckCooling
                }

                add_test!(reporter, "Cooled", |obs| {
                    expect!(obs, draw_watts < 10.0, "Load < 10 W");
                    expect!(obs, temp_c < 25.5, "Temp is < 25.5");
                });
                add_test!(reporter, "Fan turns off", |obs| {
                    expect_eq!(obs, fan_rpm, 0);
                });
                // reset in case we want to use these again later
                self.mark_temp = None;
                self.mark_time = None;
                TestStep::EndAndReport
            }
```
and the caller in the match arm:
```rust
                    TestStep::LowerLoadAndCheckCooling => {
                        let mins_passed = dv.sim_time_ms / 60_000.0;
                        let draw_watts = dv.draw_watts;
                        let temp_c = dv.temp_c;
                        let fan_rpm = dv.fan_rpm;

                        self.step = self.lower_load_and_check_cooling(mins_passed, draw_watts, temp_c, fan_rpm);
                    },
```
And again, remember to update the return value for the next step of the `load_and_check_fan` method to be `TestStep::LowerLoadAndCheckCooling` so that it chains to this one properly.

Your `cargo run --features integration-test` should now complete in about 40 seconds and look like this (your output timing may vary slightly):
```
==================================================
 Test Section Report
 Duration: 35.4803276s

[PASS] Static Values received
[PASS] First Test Data Frame received
[PASS] Check Starting Values
[PASS] Check Charger Attachment
[PASS] Temperature rises on charge
[PASS] Temperature is warm
[PASS] Fan turns on
[PASS] Cooled
[PASS] Fan turns off

 Summary: total=9, passed=9, failed=0
==================================================
```





