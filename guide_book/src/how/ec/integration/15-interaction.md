# Interaction

Our integration is fine, but what we really want to see here is how our component work together in a simulated system. To create a meaningful simulation of a system, we need to add some interactivity so that we can see how the system responds to user inputs and changes in state, in particular, increases and decreases to the system load the battery/charger system is supporting.

If we return our attention to `entry.rs`, we see in `entry_task_interactive()` a commented-out spawn of an `interaction_task()`:
```rust
    // spawner.spawn(interaction_task(shared.interaction_channel)).unwrap();
```
remove the comment characters to enable this line (or add the line if it is not present).  Then add this task and helper functions:
```rust
use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind};
use embassy_time::{Duration, Timer};

#[embassy_executor::task]
pub async fn interaction_task(tx: &'static InteractionChannelWrapper) {

    loop {
        // crossterm input poll for key events
        if event::poll(std::time::Duration::from_millis(0)).unwrap_or(false) {
            if let Ok(Event::Key(k)) = event::read() {
                handle_key(k, tx).await;
            }
        }
        // loop timing set to be responsive, but allow thread relief
        Timer::after(Duration::from_millis(33)).await;
    }
}

async fn handle_key(k:KeyEvent, tx:&'static InteractionChannelWrapper) {
    if k.kind == KeyEventKind::Press {
        match k.code {
            KeyCode::Char('>') | KeyCode::Char('.') | KeyCode::Right => {
                tx.send(InteractionEvent::LoadUp).await
            }, 
            KeyCode::Char('<') | KeyCode::Char(',') | KeyCode::Left => {
                tx.send(InteractionEvent::LoadDown).await
            },
            KeyCode::Char('1') => {
                tx.send(InteractionEvent::TimeSpeed(1)).await
            },
            KeyCode::Char('2') => {
                tx.send(InteractionEvent::TimeSpeed(2)).await
            },
            KeyCode::Char('3') => {
                tx.send(InteractionEvent::TimeSpeed(3)).await
            },
            KeyCode::Char('4') => {
                tx.send(InteractionEvent::TimeSpeed(4)).await
            },
            KeyCode::Char('5') => {
                tx.send(InteractionEvent::TimeSpeed(5)).await
            }
            KeyCode::Char('D') | KeyCode::Char('d') => {
                tx.send(InteractionEvent::ToggleMode).await
            }
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
                tx.send(InteractionEvent::Quit).await
            },
            _ => {}
        }
    }

}
```
As you see, this sends `InteractionEvent` messages in response to key presses.  The `InteractionEvent` enum is defined in `events.rs`. The handling for these events is also already in place in `system_observer.rs` in the `update()` method of `SystemObserver`.  The `LoadUp` and `LoadDown` events adjust the system load, and the `TimeSpeed(n)` events adjust the speed of time progression in the simulation.  The `ToggleMode` event switches between normal and silent modes, and the `Quit` event exits the simulation.

What's needed to complete this cycle is a listener for these events in our main integration logic.  We have already set up the `InteractionChannelWrapper` and passed it into our `ControllerCore` as `sysobs`.  Now we need to add the event listening to the `ControllerCore` task.

Add the listener task in `controller_core.rs`:
```rust
// ==== Interaction event listener task =====
#[embassy_executor::task]
pub async fn interaction_listener_task(core_mutex: &'static Mutex<RawMutex, ControllerCore>) {

    let receiver = {
        let core = core_mutex.lock().await;
        core.interaction_channel
    };

    loop {
        let event = receiver.receive().await;
        match event {
            InteractionEvent::LoadUp => {
                let sysobs = {
                    let core = core_mutex.lock().await;
                    core.sysobs
                };
                sysobs.increase_load().await;            
            },
            InteractionEvent::LoadDown => {
                let sysobs = {
                    let core = core_mutex.lock().await;
                    core.sysobs
                };
                sysobs.decrease_load().await;
            },
            InteractionEvent::TimeSpeed(s) => {
                let sysobs = {
                    let core = core_mutex.lock().await;
                    core.sysobs
                };
                sysobs.set_speed_number(s).await;
            },
            InteractionEvent::ToggleMode => {
                let sysobs = {
                    let core = core_mutex.lock().await;
                    core.sysobs
                };
                sysobs.toggle_mode().await;
            },
            InteractionEvent::Quit => {
                let sysobs = {
                    let core = core_mutex.lock().await;
                    core.sysobs
                };
                sysobs.quit().await;
            }
        }
    }
}
// (display event listener found in display_render.rs)
```

Call it from the `ControllerCore::start()` method, just after we spawn the `controller_core_task`:
```rust
        println!("spawning integration_listener_task");
        if let Err(e) = spawner.spawn(interaction_listener_task(core_mutex)) {
            eprintln!("spawn controller_core_task failed: {:?}", e);
        }        
```

You will notice that all of the handling for the interaction events is done through the `SystemObserver` instance that is part of `ControllerCore`. `SystemObserver` has helper methods both for sending the event messages and for handling them, mostly by delegating to other members.  This keeps the interaction logic nicely encapsulated.

Running now, we can use the key actions to raise or lower the system load, and change the speed of time progression. When we are done, we can hit `q` or `Esc` to exit the simulation instead of resorting to `ctrl-c`.

### An improved experience
We have so far only implemented the `RenderMode::Log` version of the display renderer. This was a simple renderer to create while we were focused on getting the integration working, and it remains a valuable tool for logging the system state in a way that provides a reviewable perspective of change over time. But next, we are going to fill out the `RenderMode::InPlace` mode to provide a more interactive, app-like simulation experience.


