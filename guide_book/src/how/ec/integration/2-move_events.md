# Configurable knobs and controls
We have multiple components, each with different settings, and which interact with one another through definable rules.  Defining these adjustable values now helps us to better visualize the infrastructure needed to support their usage and interrelationships.

## Creating project structure
In your `integration_project` directory, create a `src` directory.
Then create a `main.rs` file within `src`.  Leave it empty for now. We'll come to that shortly.
Then create the following folders within `src` that we will use for our collection of configurable settings:
- `config` - This will hold our general configuration knobs and switches in various categories
- `model` - This will hold our behavioral models, specifically our thermal behavior.
- `policy` - This will hold the decision-making policies for the charger and thermal components.
- `state` - This tracks various aspects of component state along the way.

### The config files
Add the following files within the `src/config` folder:

`config/policy_config.rs`:
```rust
#[derive(Clone)]
/// Parameters for the charger *policy* (attach/detach + current/voltage requests).
/// - Attach/Detach uses SOC hysteresis + idle gating (time since last heavy load).
/// - Current requests combine a SOC-taper target, a power-deficit boost, slew limiting,
///   and small-change hysteresis to avoid chatter.
pub struct ChargerPolicyCfg {
    /// Instantaneous discharge current (mA, positive = drawing from battery) that qualifies
    /// as “heavy use.” When load_ma >= heavy_load_ma, update `last_heavy_load_ms = now_ms`.
    pub heavy_load_ma: i32,

    /// Required idle time (ms) since the last heavy-load moment before we may **detach**.
    /// Implemented as: `since_heavy >= idle_min_ms`.
    pub idle_min_ms: u64,

    /// Minimum time (ms) since the last attach/detach change before we may **(re)attach**.
    /// Anti-chatter dwell for entering the attached state.
    pub attach_dwell_ms: u64,

    /// Minimum time (ms) since the last attach/detach change before we may **detach**.
    /// Anti-chatter dwell for leaving the attached state.
    pub detach_dwell_ms: u64,

    /// If `SOC <= attach_soc_max`, we *want to attach* (low side of hysteresis).
    pub attach_soc_max: u8,

    /// If `SOC >= detach_soc_min` **and** we’ve been idle long enough, we *want to detach*
    /// (high side of hysteresis). Keep `detach_soc_min > attach_soc_max`.
    pub detach_soc_min: u8,

    /// Minimum spacing (ms) between policy actions (e.g., recomputing/sending a new capability).
    /// Acts like a control-loop cadence limiter.
    pub policy_min_interval_ms: u64,

    /// Target voltage (mV) to use while in **CC (constant current)** charging (lower SOC).
    /// Typically below `v_float_mv`.
    pub v_cc_mv: u16,

    /// Target voltage (mV) for **CV/float** region (higher SOC). Used after CC phase.
    pub v_float_mv: u16,

    /// Upper bound (mA) on requested charge current from policy (device caps may further clamp).
    pub i_max_ma: u16,

    /// Proportional gain mapping **power deficit** (Watts) → **extra charge current** (mA),
    /// to cover system load while attached: `p_boost_ma = clamp(kp_ma_per_w * watts_deficit)`.
    pub kp_ma_per_w: f32,

    /// Hard cap (mA) on the proportional “power-boost” term so large deficits don’t overshoot.
    pub p_boost_cap_ma: u16,

    /// Maximum rate of change (mA/s) applied by the setpoint slewer. Prevents step jumps
    /// and improves stability/realism.
    pub max_slew_ma_per_s: u16,

    /// Minimum delta (mA) between current setpoint and new target before updating.
    /// If `|target - current| < policy_hysteresis_ma`, do nothing (reduces twitch).
    pub policy_hysteresis_ma: u16,
}

impl Default for ChargerPolicyCfg {
    fn default() -> Self {
        Self {
            heavy_load_ma: 800, idle_min_ms: 3000, attach_dwell_ms: 3000, detach_dwell_ms:3000,
            attach_soc_max: 90, detach_soc_min: 95, 

            policy_min_interval_ms: 3000,
            v_cc_mv: 8300,
            v_float_mv: 8400,

            i_max_ma: 4500, 
            kp_ma_per_w: 50.0, p_boost_cap_ma: 800,
            max_slew_ma_per_s: 4000, policy_hysteresis_ma: 50
        }
    }
}

#[derive(Clone)]
pub struct ThermalPolicyCfg {
    // Your existing band/hysteresis semantics
    pub temp_low_on_c: f32,    // “fan on” point / WARN-LOW
    pub temp_high_on_c: f32,   // begin ramp / WARN-HIGH
    pub fan_hyst_c: f32,       // used for both sensor & fan hysteresis

    // ODP Sensor Profile (ts::sensor::Profile)
    pub sensor_prochot_c: f32,
    pub sensor_crt_c: f32,
    pub sensor_fast_sampling_threshold_c: f32,
    pub sensor_sample_period_ms: u64,
    pub sensor_fast_sample_period_ms: u64,
    pub sensor_hysteresis_c: f32, // usually = fan_hyst_c

    // ODP Fan Profile (ts::fan::Profile)
    pub fan_on_temp_c: f32,      // typically = temp_low_on_c
    pub fan_ramp_temp_c: f32,    // typically = temp_high_on_c
    pub fan_max_temp_c: f32,     // typically = prochot or a bit under CRT
    pub fan_sample_period_ms: u64,
    pub fan_update_period_ms: u64,
    pub fan_auto_control: bool,  // true for ODP-controlled ramp
}

impl Default for ThermalPolicyCfg {
    fn default() -> Self {
        // Sensible defaults; tweak as you wish.
        let temp_low_on_c  = 27.5;
        let temp_high_on_c = 30.0;
        let fan_hyst_c     = 0.6;

        let sensor_prochot_c = 50.0;
        let sensor_crt_c     = 80.0;

        Self {
            // legacy “band” semantics
            temp_low_on_c,
            temp_high_on_c,
            fan_hyst_c,

            // sensor
            sensor_prochot_c,
            sensor_crt_c,
            sensor_fast_sampling_threshold_c: temp_high_on_c,
            sensor_sample_period_ms: 250,
            sensor_fast_sample_period_ms: 100,
            sensor_hysteresis_c: fan_hyst_c,

            // fan
            fan_on_temp_c: temp_low_on_c,
            fan_ramp_temp_c: temp_high_on_c,
            fan_max_temp_c: sensor_prochot_c, // fan full speed before PROCHOT
            fan_sample_period_ms: 250,
            fan_update_period_ms: 250,
            fan_auto_control: true,
        }
    }
}

#[derive(Clone, Default)]
/// Combined settings that affect policy
pub struct PolicyConfig {
    pub charger: ChargerPolicyCfg,
    // pub thermal: ThermalPolicyCfg,
}
```
The policy configurations for the charger work in concert with the functions we will define in `charger_policy.rs` (below).
The policy configurations for thermal mirror the policy settings used by the ODP thermal services that we will register with and attach to.

`config/sim_config.rs`:
```rust
// src/config/sim_config.rs
#[allow(unused)]
#[derive(Clone)]
/// Parameters for the simple thermal *model* (how temperature evolves).
/// Roughly: T' = (T_ambient - T)/tau_s + k_load_w * P_watts - k_fan_pct * fan_pct
pub struct ThermalModelCfg {
    /// Ambient/environment temperature in °C (the asymptote with zero load & zero fan).
    pub ambient_c: f32,

    /// Thermal time constant (seconds). Larger = slower temperature response.
    /// Used to low-pass (integrate) toward ambient + heat inputs.
    pub tau_s: f32,

    /// Heating gain per electrical power (°C/sec per Watt), or folded into your integrator
    /// as °C per tick when multiplied by P_w and dt. Higher => load heats the system faster.
    /// Typical: start small (e.g., 0.001–0.02 in your dt units) and tune until ramps look plausible.
    pub k_load_w: f32,

    /// Cooling gain per fan percentage (°C/sec per 100% fan), or °C per tick when multiplied
    /// by (fan_pct/100) and dt. Higher => fan cools more aggressively.
    /// Tune so “100% fan” can arrest/ramp down temp under expected max load.
    pub k_fan_pct: f32,

    /// Nominal battery/system voltage in mV (for converting current → power when needed).
    /// Example: P_w ≈ (load_ma * v_nominal_mv) / 1_000_000. Use an average system/battery voltage.
    pub v_nominal_mv: u16,

    /// fractional heat contributions of charger/charging power
    /// Rough guide: 5–10% PSU loss
    /// °C per Watt of charge power
    pub k_psu_loss: f32,

    /// fractional heat contributions of charger/charging power
    /// Rough guide: a few % battery heating during charge.
    /// °C per Watt of charge power
    pub k_batt_chg: f32,
}

#[allow(unused)]
#[derive(Clone)]
/// settings applied to the simulator behavior itself
pub struct TimeSimCfg {
    /// controls the speed of the simulator -- a multiple of simulated seconds per 1 real-time second.
    pub sim_multiplier: f32, 
}

#[allow(unused)]
#[derive(Clone)]
/// parameters that define the capabilities of the integrated charging system
pub struct DeviceCaps {
    /// maximum current (mA) of device
    pub max_current_ma: u16, // 3000 for mock
    /// maximum voltage (mV) of device
    pub max_voltage_mv: u16, // 15000 for mock
}

#[allow(unused)]
#[derive(Clone)]
/// Combined settings that affect the simulation behavior.
pub struct SimConfig {
    pub time: TimeSimCfg,
    pub thermal: ThermalModelCfg,
    pub device_caps: DeviceCaps,
}

impl Default for SimConfig {
    fn default() -> Self {
        Self {
            time: TimeSimCfg { sim_multiplier: 25.0 },
            thermal: ThermalModelCfg {
                ambient_c: 23.0,
                tau_s: 8.0,
                k_load_w: 0.16,
                k_fan_pct: 0.027,   // how effective cooling is
                v_nominal_mv: 8300,
                k_psu_loss: 0.04,   // % of chg power shows up as heat in the box
                k_batt_chg: 0.03,   // % of battery heat
            },
            device_caps: DeviceCaps { max_current_ma: 4800, max_voltage_mv: 15000 },
        }
    }
}
```
These simulation configs give us some flexibility in how we compute the effects of type/physics for our virtual device implementations.

`config/ui_config.rs`:
```rust

#[derive(Clone, PartialEq)]
#[allow(unused)]
/// Defines which types of rendering we can choose from
/// `InPlace` uses ANSI-terminal positioning for a static position display
/// `Log` uses simple console output, useful for tracking record over time.
pub enum RenderMode { InPlace, Log }

#[derive(Clone)]
#[allow(unused)]
/// Combined UI settings
pub struct UIConfig {
    /// InPlace or Log
    pub render_mode: RenderMode,
    /// Initial load (mA) to apply prior to any interaction
    pub initial_load_ma: u16,
}
impl Default for UIConfig {
    fn default() -> Self {
        Self { render_mode: RenderMode::InPlace, initial_load_ma: 1200 }
    }
}
```
And we need a `mod.rs` file within the folder to bring these together for inclusion:

`config/mod.rs`:
```rust
// config
pub mod sim_config;
pub mod policy_config;
pub mod ui_config;

pub use sim_config::SimConfig;
pub use policy_config::PolicyConfig;
pub use ui_config::UIConfig;

#[derive(Clone, Default)]
pub struct AllConfig {
    pub sim: SimConfig,
    pub policy: PolicyConfig,
    pub ui: UIConfig,
}
```
A quick scan of these values shows that these represent various values one may want to adjust in order to model different component capabilities, behaviors, or conditions.  The final aggregate, `AllConfig` brings all of these together into one nested structure. The `Default` implementations for each simplify the normal setting of these values at construction time.  These values can be adjusted to suit your preferences. If you are so inclined, you might even consider importing these values from a configuration file, but we won't be doing that here.

Now let's continue this pattern for the `policy`, `state`, and `model` categories as well.
`policy/charger_policy.rs`:
```rust
use embedded_services::power::policy::PowerCapability;
use crate::config::policy_config::ChargerPolicyCfg;
use crate::config::sim_config::DeviceCaps;

pub fn derive_target_ma(cfg: &ChargerPolicyCfg, dev: &DeviceCaps, soc: u8, load_ma: i32) -> u16 {
    let i_max = cfg.i_max_ma.min(dev.max_current_ma);
    let cover_load = (load_ma + cfg.heavy_load_ma as i32).max(0) as u16;

    // piecewise taper
    let soc_target = if soc < 60 { i_max }
        else if soc < 85 { (i_max as f32 * 0.80) as u16 }
        else if soc < cfg.attach_soc_max { (i_max as f32 * 0.60) as u16 }
        else if soc < 97 { (i_max as f32 * 0.35) as u16 }
        else { (i_max as f32 * 0.15) as u16 };

    cover_load.max(soc_target).min(i_max)
}

pub fn p_boost_ma(kp_ma_per_w: f32, p_boost_cap_ma: u16, watts_deficit: f32) -> u16 {
    (kp_ma_per_w * watts_deficit.max(0.0)).min(p_boost_cap_ma as f32) as u16
}

pub fn slew_toward(current: u16, target: u16, dt_s: f32, rate_ma_per_s: u16) -> u16 {
    let max_delta = (rate_ma_per_s as f32 * dt_s) as i32;
    let delta = target as i32 - current as i32;
    if delta.abs() <= max_delta { target }
    else if delta > 0 { (current as i32 + max_delta) as u16 }
    else { (current as i32 - max_delta) as u16 }
}

pub fn build_capability(cfg: &ChargerPolicyCfg, dev: &DeviceCaps, soc: u8, current_ma: u16) -> PowerCapability {
    let v_target = if soc < cfg.attach_soc_max { cfg.v_cc_mv } else { cfg.v_float_mv };
    PowerCapability {
        voltage_mv: v_target.min(dev.max_voltage_mv),
        current_ma: current_ma.min(dev.max_current_ma),
    }
}

pub struct AttachDecision {
    pub attach: bool,   // true=attach, false=detach
    pub do_change: bool,
}

#[inline]
fn dwell_ok(was_attached: bool, since_change_ms: u64, cfg: &ChargerPolicyCfg) -> bool {
    if was_attached {
        since_change_ms >= cfg.detach_dwell_ms
    } else {
        since_change_ms >= cfg.attach_dwell_ms
    }
}

#[inline]
fn ms_since(t:u64, now:u64) -> u64 {
    now - t
}

pub fn decide_attach(
    cfg: &ChargerPolicyCfg,
    was_attached: bool,
    soc: u8,                 // 0..=100
    last_psu_change_ms: u64,  // when we last toggled attach/detach
    last_heavy_load_ms: u64,  // when we last saw heavy load
    now_ms: u64,
) -> AttachDecision {
    let since_change = ms_since(last_psu_change_ms, now_ms);
    let since_heavy  = ms_since(last_heavy_load_ms,  now_ms);

    // Hysteresis-based targets
    let want_attach = soc <= cfg.attach_soc_max;
    let want_detach = (soc >= 100 && was_attached) || (soc >= cfg.detach_soc_min && since_heavy >= cfg.idle_min_ms);

    let can_change  = dwell_ok(was_attached, since_change, cfg);

    // Priority rules:
    // 1) If we are attached and conditions say detach, and dwell is satisfied -> detach.
    // 2) If we are detached and conditions say attach, and dwell is satisfied -> attach.
    // 3) Otherwise no-op.
    if was_attached {
        if want_detach && can_change {
            return AttachDecision { attach: false, do_change: true };
        }
    } else {
        if want_attach && can_change {
            return AttachDecision { attach: true, do_change: true };
        }
    }

    AttachDecision { attach: was_attached, do_change: false }
}
```
The `charger_policy.rs` functions are controlled by the charger configurations in `policy_cfg.rs` and define the rules by which we attach and detach the charger.

`policy/mod.rs`:
```rust
//policy
pub mod charger_policy;
```
We only need a charger policy defined here.  Thermal policy is provided by the ODP services.

`state/charger_state.rs`:
```rust

pub struct ChargerState {
    pub requested_ma: u16,
    pub last_policy_sent_at_ms: u64,
    pub was_attached: bool,
    pub last_psu_change_ms: u64,
    pub last_heavy_load_ms: u64,
}

impl Default for ChargerState {
    fn default() -> Self {
        Self {
            requested_ma: 0,
            last_policy_sent_at_ms: 0,
            was_attached: false,
            last_psu_change_ms: 0,
            last_heavy_load_ms: 0,
        }
    }
}
```

`state/sim_state.rs`:
```rust
use embassy_time::Instant;

pub struct SimState {
    pub last_update: Instant,
}

impl Default for SimState {
    fn default() -> Self {
        Self { last_update: Instant::now() }
    }
}
```

`state/mod.rs`:
```rust
// state
pub mod charger_state;
pub mod sim_state;

pub use charger_state::ChargerState;
pub use sim_state::SimState;
```
These states are used to track the current condition of the simulation and its components in action over time.

`model/thermal_model.rs`:
```rust
use crate::config::sim_config::ThermalModelCfg;

// thermal_model.rs
pub fn step_temperature(
    t: f32,
    load_ma: i32,
    fan_rpm: u16,
    fan_min_rpm: u16,
    fan_max_rpm: u16,
    cfg: &ThermalModelCfg,
    dt_s: f32,
    chg_w: f32, // charge power in Watts (0 if not charging)
) -> f32 {
    let load_w = (load_ma.max(0) as f32) * (cfg.v_nominal_mv as f32) / 1_000_000.0;

    // Fractional heat contributions
    let psu_heat_w  = cfg.k_psu_loss * chg_w;   // DC-DC inefficiency + board losses
    let batt_heat_w = cfg.k_batt_chg * chg_w;   // battery internal resistance during charge

    // Normalize RPM → 0..1 → 0..100% (clamped)
    let fan_frac = if fan_max_rpm <= fan_min_rpm {
        0.0
    } else {
        ((fan_rpm.saturating_sub(fan_min_rpm)) as f32
            / (fan_max_rpm - fan_min_rpm) as f32)
            .clamp(0.0, 1.0)
    };
    let fan_pct = 100.0 * fan_frac;

    // Combined drive: ambient + load heat + charger/battery heat - fan cooling
    let drive = cfg.ambient_c
        + cfg.k_load_w * load_w
        + psu_heat_w
        + batt_heat_w
        - cfg.k_fan_pct * fan_pct;

    let alpha = (dt_s / cfg.tau_s).clamp(0.0, 1.0);
    (t + alpha * (drive - t)).max(cfg.ambient_c)
}
```
`model/mod.rs`:
```rust
// model
pub mod thermal_model;
```
The thermal model is used to express the physical effects of the cooling airflow from the fan.  You will recall that the physical effects of the virtual battery have already been implemented via the `tick()` method of `VirtualBattery`, which also computes a temperature generated by the battery itself.  This thermal model complements this in this integrated simulation by applying a cooling effect function.



## Consolidating events
Earlier we mentioned that we would simplify our comms implementation in this exercise by consolidating the message types onto a single communication channel bus.  

> ### Why one bus?
> - easier tracing
> - simpler buffering
> - less churn when adding new message types
> ----

Let's define a single enum to help us with that now:

Create `events.rs` with this content:
```rust
use embedded_services::power::policy::charger::ChargerEvent;
use ec_common::events::ThermalEvent;
use embedded_services::power::policy::PowerCapability;

#[allow(unused)]
#[derive(Debug)]
pub enum BusEvent {
    Charger(ChargerEvent),
    ChargerPolicy(PowerCapability), // associates with PolicyEvent::PowerConfiguration for our handling
    Thermal(ThermalEvent),
}
```
Notice in this code it refers to `ec_common::events::ThermalEvent` but we don't have our `ThermalEvent` in `ec_common`.  We had defined that as part of our `thermal_project` exercise, but did not add it to the `ec_common` `events.rs` file.  We can copy the definition from there and add it now, so that our new `ec_common/src/events.rs` file is a common location for events defined up to this point, and looks like this:
```rust

//! Common types and utilities for the embedded controller (EC) ecosystem.
/// BatteryEvent is defined at `battery_service::context::BatteryEvent`
/// ChargerEvent is defined at `embedded_services::power::policy::charger::ChargerEvent`

/// -------------------- Thermal --------------------

/// Events to announce thermal threshold crossings
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ThresholdEvent {
    None,
    OverHigh,
    UnderLow
}

/// Request to increase or decrease cooling efforts
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CoolingRequest { 
    Increase, 
    Decrease 
}

/// Resulting values to apply to accommodate request
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CoolingResult {
    pub new_level: u8,
    pub target_rpm_percent: u8,
    pub spinup: Option<SpinUp>,
}

/// One-shot spin-up hint: force RPM for a short time so the fan actually starts.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SpinUp {
    pub rpm: u16,
    pub hold_ms: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ThermalEvent {
    TempSampleC100(u16), // (int) temp_c * 100 
    Threshold(ThresholdEvent),
    CoolingRequest(CoolingRequest)
}
```
Now all of our event messaging can be referred to from the single enumeration source `BusEvent`, and our handlers can dispatch accordingly.

We also need to add this to the `lib.rs` file of `ec_common` to make these types available to the rest of the crate:

```rust
pub mod mutex;
pub mod mut_copy;
pub mod espi_service;
pub mod fuel_signal_ready;
pub mod test_helper;
pub mod events;
```