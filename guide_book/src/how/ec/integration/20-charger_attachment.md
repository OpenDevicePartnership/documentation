# Checking Charger Attachment

Let's continue on with the next step we've outlined in our `TestStep` series: `TestStep::CheckChargerAttach`.

To do this, create a new member function for this:
```rust
            fn check_charger_attach(&mut self, mins_passed: f32, soc:f32, charge_watts:f32) -> TestStep {
                let reporter = &mut self.reporter;
                // Fail if we don't see our starting conditions within a reasonable time
                if mins_passed > 30.0 { // should occur before 30 minutes simulation time
                    add_test!(reporter, "Attach Charger", |obs| {
                        obs.fail("Time expired waiting for attach");
                    });
                }
                // wait until we see evidence of charger attachment
                if charge_watts == 0.0 { 
                    return TestStep::CheckChargerAttach; // stay on this task
                }
                add_test!(reporter, "Check Charger Attachment", |obs| {
                    expect!(obs, soc <= 90.0, "Attach expected <= 90% SOC");
                });
                // TestStep::RaiseLoadAndCheckTemp // go to next step   
                TestStep::EndAndReport

            }
```
This is a little different because it first checks for qualifying (or disqualifying error) conditions before it begins the actual test closure.  
First, it checks to see if we've timed out -- using simulation time, and assuming the starting values that we've already verified, we expect the battery to discharge to the attach point in under 30 minutes.  If this condition fails, we create a directly failing test to report it.
We then check to see if the charger is attached, which is evidenced by `charge_watts > 0.0` until this is true, we return `TestStep::CheckChargerAttach` so that we continue to be called each frame until then.
Once these conditional checks are done, we can test what it means to be in attached state and proceed to the next step, which in this case is `EndAndReport` until we add another test.

On that note, edit the return of `check_starting_values()` to now be `TestStep::CheckChargerAttach` so that it chains to this one.

Now, in the match arms for this, add this caller:
```rust
                    TestStep::CheckChargerAttach => {
                        let mins_passed = dv.sim_time_ms / 60_000.0;
                        let soc = dv.soc_percent;
                        let charge_watts = dv.charge_watts;

                        self.step = self.check_charger_attach(mins_passed, soc, charge_watts);
                    },
```

finally, remove this `println!` because these will start to become annoying at this point:
```rust
                println!("Step {:?}", self.step);
```

and when run with `cargo run --features integration-test` you should see:
```
🔬 Integration testing starting...
 ☄ attaching charger
==================================================
 Test Section Report
[PASS] Static Values received
[PASS] First Test Data Frame received
[PASS] Check Starting Values
[PASS] Check Charger Attachment

 Summary: total=4, passed=4, failed=0
==================================================
```

Next, we'll look at what the effects of increasing the system load have to our scenario, but first we need to provide a mechanism for that.


