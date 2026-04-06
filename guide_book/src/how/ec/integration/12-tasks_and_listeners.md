# Tasks, Listeners, and Handlers

So, our first test shows us our nascent scaffolding is working.  We see the the `println!` output from our `ControllerCore` tapped trait methods, and we see the pump continue to run through tap point of `get_dynamic_data()`.

We can use this tap point to orchestrate interaction with the other components.  But before we do that, we need to establish an independent way to communicate with these components through our message channels.  Although we are within the ControllerCore context and have direct access to the component methods, we want to preserve the modularity of our components and keep them isolated from each other. Messages allow us to do this without locking ourselves into a tightly-coupled design.

>----
> ### Rule of Thumb -- locking the core
> - __Lock once, copy out, unlock fast.__ Read all the field you need locally then release the lock before computation or I/O.
> - __Never hold a lock across `.await`.__ Extract data you'll need, drop the guard, _then_ `await`.
> - __Prefer one short lock over many tiny locks.__ It reduces contention and avoids inconsistent snapshots.
>
> ---

Let's start with the general listening task of the `ControllerCore`.  This task will listen for messages on the channels we have established, and then forward these messages to the appropriate handlers.

Add this to `controller_core.rs`:

```rust
// ==== General event listener task =====
#[embassy_executor::task]
pub async fn controller_core_task(receiver:Receiver<'static, RawMutex, BusEvent, BUS_CAP>, core_mutex: &'static Mutex<RawMutex, ControllerCore>) {

    loop {
        let event = receiver.receive().await;
        match event {
            BusEvent::Charger(e)    => handle_charger(core_mutex, e).await,
            BusEvent::Thermal(e)    => handle_thermal(core_mutex, e).await,
            BusEvent::ChargerPolicy(_) => handle_charger_policy(core_mutex, event).await,
        }
    }
}
```
and add the spawn for this task in the `start()` method of `ControllerCore`:

```rust
    /// start event processing with a passed mutex 
    pub fn start(core_mutex: &'static Mutex<RawMutex, ControllerCore>, spawner: Spawner) {
        
        println!("In ControllerCore::start()"); 

        println!("spawning controller_core_task");
        if let Err(e) = spawner.spawn(controller_core_task(BUS.receiver(), core_mutex)) {
            eprintln!("spawn controller_core_task failed: {:?}", e);
        }
    }
```

This establishes a general listener task that will receive messages from the bus and forward them to specific handlers.  We will define these handlers next.  Add these handler functions to `controller_core.rs`:

```rust
async fn handle_charger(core_mutex: &'static Mutex<RawMutex, ControllerCore>, event: ChargerEvent) {

    let device = {
        let core = core_mutex.lock().await;
        core.charger_service_device
    };

    match event {
        ChargerEvent::Initialized(PsuState::Attached) => {
        }

        ChargerEvent::PsuStateChange(PsuState::Attached) => {
            println!(" ☄ attaching charger");
            let _ = device.execute_command(PolicyEvent::InitRequest).await; // let the policy attach and ramp per latest PowerConfiguration.
        }

        ChargerEvent::PsuStateChange(PsuState::Detached) |
        ChargerEvent::Initialized(PsuState::Detached) => {
            println!(" ✂ detaching charger");
            let zero_cap = PowerCapability {voltage_mv: 0, current_ma: 0};
            let _ = device.execute_command(PolicyEvent::PolicyConfiguration(zero_cap)).await; // should detach with this.
        }

        ChargerEvent::Timeout => {
            println!("⏳ Charger Timeout occurred");
        }
        ChargerEvent::BusError => {
            println!("❌ Charger Bus error occurred");
        }
    }
}

async fn handle_charger_policy(core_mutex: &'static Mutex<RawMutex, ControllerCore>, evt: BusEvent) {
    match evt {
        BusEvent::ChargerPolicy(cap)=> {
            
            // Treat current==0 as a detach request
            if cap.current_ma == 0 {
                let mut core = core_mutex.lock().await;
                let _ = core.charger.detach_handler().await;
                let _ = core.charger.charging_current(0).await;
            } else {
                let mut core = core_mutex.lock().await;
                // Make sure we’re “attached” at the policy layer
                let _ = core.charger.attach_handler(cap).await;

                // Program voltage then current; the mock should update its internal state
                let _ = core.charger.charging_voltage(cap.voltage_mv).await;
                let _ = core.charger.charging_current(cap.current_ma).await;
            }

            // echo what the mock reports now
            if is_log_mode(core_mutex).await {
                let core = core_mutex.lock().await;
                let now = { core.charger.charger.state.lock().await.current() };
                println!("🔌 Applied {:?}; charger now reports {} mA", cap, now);
            }
        }
        _ => {}
    }
}

async fn handle_thermal(core_mutex: &'static Mutex<RawMutex, ControllerCore>, evt: ThermalEvent) {
    match evt {
        ThermalEvent::TempSampleC100(cc) => {
            let temp_c = cc as f32 / 100.0;
            {
                let core = core_mutex.lock().await;
                let mut ctrl = core.sensor.controller().lock().await;
                ctrl.set_sim_temp(temp_c);
            }
        },
        _ => {}
    }
}
```
We can see that these handlers are fairly straightforward.  It is here that we _do_ call into the integrated component internals, _after_ receiving the message that directs the action.  Each handler locks the `ControllerCore` mutex, and then call the appropriate methods on the components. The implementation of these actions is very much like what we have done in the previous integrations.  One notable difference, however, is in `handle_charger` we call upon the registered `charger_service_device` to execute the `PolicyEvent` commands.  We do this to take advantage of the charger policy handling that is built into the embedded-services charger device.  This allows us to offload some of the policy management to the embedded-services layer, which is a good thing.  In previous integrations, we chose to implement this ourselves.  Both approaches are valid, but using the built-in policy handling allows for a predictable and repeatable behavior that is consistent with other embedded-services based implementations.

## The Charger Task and Charger Policy Task
On that subject, it's not enough to just call `device_command` on the charger device when we receive a `ChargerEvent`.  We also need to start the charger service and have a task that listens for charger policy events and sends those to the charger device.  This is because the charger policy events may be generated from other parts of the system, such as the battery service or the thermal management system, and we need to have a dedicated task to handle these events.

Let's add those two tasks now:
```rust
// helper for log mode check
pub async fn is_log_mode(core_mutex: &'static Mutex<RawMutex, ControllerCore>) -> bool {
    let core = core_mutex.lock().await;
    core.cfg.ui.render_mode == RenderMode::Log
}

#[embassy_executor::task]
async fn start_charger_task(core_mutex: &'static Mutex<RawMutex, ControllerCore>) {

    let p = is_log_mode(core_mutex).await;
    let device = {
        let core = core_mutex.lock().await;
        core.charger_service_device
    };

    if p {println!("start_charger_task");}
    if p {println!("waiting for yield");}
    // give a tick to start before continuing to avoid possible race
    embassy_futures::yield_now().await;         

    // Now issue commands and await responses
    if p {println!("issuing CheckReady and InitRequest to charger device");}
    let _ = device.execute_command(PolicyEvent::CheckReady).await;
    let _ = device.execute_command(PolicyEvent::InitRequest).await;
}

// ==== Charger subsystem event listener ====
#[embassy_executor::task]
pub async fn charger_policy_event_task(core_mutex: &'static Mutex<RawMutex, ControllerCore>) {

    let p = is_log_mode(core_mutex).await;
    let device = {
        let core = core_mutex.lock().await;
        core.charger_service_device
    };

    loop {
        match device.wait_command().await {
            PolicyEvent::CheckReady => {
                if p {println!("Charger PolicyEvent::CheckReady received");}
                let res = {
                    let mut core = core_mutex.lock().await;
                    core.charger.is_ready().await
                }
                .map(|_| Ok(ChargerResponseData::Ack))
                .unwrap_or_else(|_| Err(ChargerError::Timeout));
                device.send_response(res).await;
            }
            PolicyEvent::InitRequest => {
                if p {println!("Charger PolicyEvent::InitRequest received");}
                let res = {
                    let mut core = core_mutex.lock().await;
                    core.charger.init_charger().await
                }
                .map(|_| Ok(ChargerResponseData::Ack))
                .unwrap_or_else(|_| Err(ChargerError::BusError));
                device.send_response(res).await;
            }
            PolicyEvent::PolicyConfiguration(cap) => {
                if p {println!("Charger PolicyEvent::PolicyConfiguration received {:?}", cap);}
                device.send_response(Ok(ChargerResponseData::Ack)).await; // ack so caller can continue
                let core = core_mutex.lock().await;
                let _ = core.try_send(BusEvent::ChargerPolicy(cap));
            }
        }
    }
}
```


> ---
> ### Rule of thumb --`send` vs `try_send`
> - Use `send` when in an async context for must-deliver events (rare, low-rate control/path): it awaits and guarantees delivery order.
> - Use `try_send` for best effort or high-rate events, or from a non-async context.  It returns immediately. Check the error for failure if the bus is full.
> - If dropping is unacceptable but backpressure is possible, keep retrying
> - Log drops from `try_send` to catch buffer capacity issues early on.
>
> ----


You may have noticed that we also snuck in a helper function `is_log_mode()` to check if we are in log mode.  This is used to control the verbosity of the output from these tasks.  This will make more sense once we have the display and interaction system in place.

We also need to spawn these tasks in the `start()` method of `ControllerCore`.  Add these spawns to the `start()` method:

```rust
        println!("spawning start_charger_task");
        if let Err(e) = spawner.spawn(start_charger_task(core_mutex)) {
            eprintln!("spawn start_charger_task failed: {:?}", e);
        }
        println!("spawning charger_policy_event_task");
        if let Err(e) = spawner.spawn(charger_policy_event_task(core_mutex)) {
            eprintln!("spawn charger_policy_event_task failed: {:?}", e);
        }
```

Now the handling for charger and thermal events are in place.  Now we can begin to implement the integration logic that binds these components together.
