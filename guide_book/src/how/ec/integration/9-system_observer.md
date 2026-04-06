
# The SystemObserver

Before we can construct our `ControllerCore`, we still need a `SystemObserver` and `InteractionChannelWrapper` to be defined.

The `SystemObserver` is the conduit to display output and communicates with a `DisplayRenderer` used to portray output in various ways.  The renderer itself is message-driven, as are user interaction events, so we will start by going back into `entry.rs` and adding both the `DisplayChannelWrapper` and `InteractionChannelWrapper` beneath the other "Channel Wrapper" definitions for Battery, Charger, and Thermal communication.  
```rust
pub struct DisplayChannelWrapper(pub Channel<RawMutex, DisplayEvent, CHANNEL_CAPACITY>);
#[allow(unused)]
impl DisplayChannelWrapper {
    pub async fn send(&self, e: DisplayEvent) { self.0.send(e).await }
    pub async fn receive(&self) -> DisplayEvent { self.0.receive().await }
}
impl EventChannel for DisplayChannelWrapper {
    type Event = DisplayEvent;
    fn try_send(&self, e: DisplayEvent) -> Result<(), MailboxDelegateError> {
        self.0.try_send(e).map_err(|_| MailboxDelegateError::MessageNotFound)
    }
}
pub struct InteractionChannelWrapper(pub Channel<RawMutex, InteractionEvent, CHANNEL_CAPACITY>);
impl InteractionChannelWrapper {
    pub async fn send(&self, e: InteractionEvent) { self.0.send(e).await }
    pub async fn receive(&self) -> InteractionEvent { self.0.receive().await }
}
impl EventChannel for InteractionChannelWrapper {
    type Event = InteractionEvent;
    fn try_send(&self, e: InteractionEvent) -> Result<(), MailboxDelegateError> {
        self.0.try_send(e).map_err(|_| MailboxDelegateError::MessageNotFound)
    }
}
```

Now, let's create `system_observer.rs` and give it this content to start:
```rust
use crate::events::{DisplayEvent};
use crate::display_models::{DisplayValues, StaticValues, InteractionValues, Thresholds};
use crate::entry::DisplayChannelWrapper;
use embassy_time::{Instant, Duration};
use ec_common::mutex::{Mutex, RawMutex};

struct ObserverState {
    sv: StaticValues,         // static values 
    dv: DisplayValues,        // current working frame
    last_sent: DisplayValues, // last emitted frame
    last_emit_at: Instant,
    first_emit: bool,
    interaction: InteractionValues,
    last_speed_number: u8
}

pub struct SystemObserver {
    state: Mutex<RawMutex, ObserverState>,
    thresholds: Thresholds,
    v_nominal_mv: u16,
    min_emit_interval: Duration,
    display_tx: &'static DisplayChannelWrapper,
}
impl SystemObserver {
    pub fn new(thresholds: Thresholds, v_nominal_mv: u16, display_tx: &'static DisplayChannelWrapper) -> Self {
        let now = Instant::now();
        Self {
            state: Mutex::new(ObserverState {
                sv: StaticValues::new(),
                dv: DisplayValues::new(),            // default starting values
                last_sent: DisplayValues::new(),     // default baseline
                last_emit_at: now,
                first_emit: true,
                interaction: InteractionValues::default(),
                last_speed_number: 0
            }),
            thresholds,
            v_nominal_mv,
            min_emit_interval: Duration::from_millis(100),
            display_tx,
        }
    }

    pub async fn increase_load(&self) {
        let mut guard = self.state.lock().await;
        guard.interaction.increase_load();
    }
    pub async fn decrease_load(&self) {
        let mut guard = self.state.lock().await;
        guard.interaction.decrease_load();
    }
    pub async fn set_speed_number(&self, speed_num: u8) {
        let mut guard = self.state.lock().await;
        guard.interaction.set_speed_number(speed_num);
    }
    pub async fn interaction_snapshot(&self) -> InteractionValues {
        let guard = self.state.lock().await;
        guard.interaction
    }

    pub async fn toggle_mode(&self) {
        let mut guard = self.state.lock().await;
        guard.last_emit_at = Instant::now();
        guard.first_emit   = true;
        self.display_tx.send(DisplayEvent::ToggleMode).await; 
    }
    pub async fn quit(&self) {
        self.display_tx.send(DisplayEvent::Quit).await; 
    }

    pub async fn set_static(&self, new_sv: StaticValues) {
        let mut guard = self.state.lock().await;
        guard.sv = new_sv;
        self.display_tx.send(DisplayEvent::Static(guard.sv.clone())).await; 
    }

    /// Full-frame update from ControllerCore
    pub async fn update(&self, mut new_dv: DisplayValues, ia: InteractionValues) {
        // Derive any secondary numbers in one place (keeps UI/logs consistent).
        derive_power(&mut new_dv, self.v_nominal_mv);

        let mut guard = self.state.lock().await;
        guard.dv = new_dv;

        let now = Instant::now();
        let should_emit =
            guard.first_emit ||
            (ia.sim_speed_number != guard.last_speed_number) ||
            (now - guard.last_emit_at >= self.min_emit_interval &&
            diff_exceeds(&guard.dv, &guard.last_sent, &self.thresholds));

        if should_emit {
            self.display_tx.send(DisplayEvent::Update(guard.dv.clone(), ia)).await; 
            guard.last_sent   = guard.dv.clone();
            guard.last_emit_at = now;
            guard.first_emit   = false;
            guard.last_speed_number = ia.sim_speed_number;
        }
    }
}

// ------- helpers (keep them shared so renderers never recompute differently) -------
fn derive_power(dv: &mut DisplayValues, v_nominal_mv: u16) {
    let draw_w   = (dv.load_ma as i32 * v_nominal_mv as i32) as f32 / 1_000_000.0;
    let charge_w = (dv.charger_ma as i32 * v_nominal_mv as i32) as f32 / 1_000_000.0;
    dv.draw_watts   = ((draw_w   * 10.0).round()) / 10.0;
    dv.charge_watts = ((charge_w * 10.0).round()) / 10.0;
    dv.net_watts    = (( (dv.charge_watts - dv.draw_watts) * 10.0).round()) / 10.0;
    dv.net_batt_ma  = dv.charger_ma as i16 - dv.load_ma as i16;
}

fn diff_exceeds(cur: &DisplayValues, prev: &DisplayValues, th: &Thresholds) -> bool {
    (cur.draw_watts - prev.draw_watts).abs() >= th.load_w_delta ||
    (cur.soc_percent - prev.soc_percent).abs() >= th.soc_pct_delta ||
    (cur.temp_c - prev.temp_c).abs() >= th.temp_c_delta ||
    (th.on_fan_change)
}
```

and to fill this out, we need to add to our `display_models.rs` file to define values used for Interaction and to define threshold ranges for the display.

Add these definitions to `display__models.rs`:
```rust
#[allow(unused)]
#[derive(Clone, Copy)]
/// thresholds of change to warrant a display update
pub struct Thresholds {
    /// minimum load change to report
    /// e.g., 0.2 W
    pub load_w_delta: f32,
    /// minimum soc change to report
    /// e.g., 0.5 %
    pub soc_pct_delta: f32,
    /// minimum temperature change to report
    /// e.g., 0.2 °C
    pub temp_c_delta: f32,
    /// report if fan changes.
    /// `true`` to update display if fan state changes
    pub on_fan_change: bool,  

    /// maximum wattage we can draw from system
    pub max_load: f32,  
    /// warning we are getting hot
    pub warning_temp: f32,
    /// we are too hot 
    pub danger_temp: f32,
    /// soc % is getting low
    pub warning_charge: f32,
    /// soc % is too low.. power fail imminent 
    pub danger_charge: f32, 
}
impl Thresholds {
    pub fn new() -> Self {
        Self {
            load_w_delta: 0.5,
            soc_pct_delta: 0.1,
            temp_c_delta: 0.5,
            on_fan_change: true,

            max_load: 100.0, // 100W peak draw
            warning_temp: 28.0, // 28 deg C (82.4 F) 
            danger_temp: 34.0,  // 34 deg C (93.2 F) 
            warning_charge: 20.0, // <20% remaining
            danger_charge: 8.0, // <8% remaining
        }
    }
}
#[derive(Debug, Clone, Copy)]
pub struct InteractionValues {
    pub system_load: u16,
    pub sim_speed_number: u8,
    pub sim_speed_multiplier: f32
}
const LOAD_INCREMENT: u16 = 100;  // mA
const LOAD_MIN: u16 = 0;
const LOAD_MAX: u16 = 5000;

const SPEED_SETTING : [u8; 5] = [1, 10, 25, 50, 100];

impl InteractionValues {
    pub fn increase_load(&mut self) {
        self.system_load = clamp_load(self.system_load.saturating_add(LOAD_INCREMENT));
    }
    pub fn decrease_load(&mut self) {
        self.system_load = clamp_load(self.system_load.saturating_sub(LOAD_INCREMENT));
    }
    pub fn set_speed_number(&mut self, mut num:u8) {
        if num < 1 { num = 1;}
        if num > 5 { num = 5;}
        self.sim_speed_number = num;
        let idx:usize = num as usize -1;
        self.sim_speed_multiplier = SPEED_SETTING[idx] as f32;
    }
    pub fn get_speed_number_and_multiplier(&self) -> (u8, f32) {
        (self.sim_speed_number, self.sim_speed_multiplier)
    }
}

impl Default for InteractionValues {
    fn default() -> Self {
        Self {
            system_load: 1200,
            sim_speed_number: 3,
            sim_speed_multiplier: 25.0
        }
    }
}

//-- helper functions
#[inline]
fn clamp_load(v: u16) -> u16 {
    v.clamp(LOAD_MIN, LOAD_MAX)
}

/// Power/units helpers for consistent display & logs.
///
/// Conventions:
/// - Currents are mA (signed where net flow can be negative).
/// - Voltages are mV.
/// - Watts are f32, rounded for display to 0.1 W.
/// - Positive current into the system is "charger input"; positive load is "system draw".
/// - Net battery current = charger_ma - load_ma (mA).
/// - Net watts = charge_watts - draw_watts (W).
#[inline]
pub fn mw_from_ma_mv(ma: i32, mv: u16) -> i32 {
    // exact integer math in mW to avoid float jitter for logs
    (ma as i64 * mv as i64 / 1000) as i32
}

#[inline]
pub fn w_from_ma_mv(ma: i32, mv: u16) -> f32 {
    // convenience for UI (single rounding site)
    mw_from_ma_mv(ma, mv) as f32 / 1000.0
}

#[inline]
pub fn round_w_01(w: f32) -> f32 {
    (w * 10.0).round() / 10.0
}
```

and these definitions to `events.rs`:
```rust
use crate::display_models::{StaticValues, DisplayValues, InteractionValues};


#[allow(unused)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum RenderMode {
    InPlace,                // ANSI Terminal application
    Log                     // line-based console output
}

#[allow(unused)]
#[derive(Debug)]
pub enum DisplayEvent {
    Update(DisplayValues, InteractionValues),   // observer pushes new values to renderer
    Static(StaticValues),    // observer pushes new static values to renderer
    ToggleMode,             // switch between Log and InPlace RenderMode (forwarded from interactin)
    Quit,                   // exit simulation (forwarded from interaction)
}

#[allow(unused)]
#[derive(Debug)]
pub enum InteractionEvent {
    LoadUp,                 // increase system load
    LoadDown,               // decrease system load
    TimeSpeed(u8),          // set time multiplier via speed number
    ToggleMode,             // switch between Log and InPlace RenderMode (forward to Display)
    Quit,                   // exit simulation (forward to Display)
}
```

For now, we only need to provide `SystemObserver` and related structures as dependencies to the system so that we can construct a minimal standup for our first tests.  We'll outfit it with the Display and Interaction features later. 
