
### Provide an API for controlling the lights

We now have a handler that will tell us when the user has pressed the button, but we still need a way to turn on the lights.
Continuing the theme of ODP-style modularity, we will declare an API for light control here.

###### LedApi.rs
```rust

#![no_std]
#![no_main]

let mut status_led;

fn lights_init() -> ! {
    let device_periphs = pac::Peripherals::take().unwrap();
    let mut reset_and_clock_control = device_periphs.RCC.constrain();

    // initialize user leds
    let mut gpioe = device_periphs.GPIOE.split(&mut reset_and_clock_control.ahb);
    let leds = Leds::new(
        gpioe.pe8,
        gpioe.pe9,
        gpioe.pe10,
        gpioe.pe11,
        gpioe.pe12,
        gpioe.pe13,
        gpioe.pe14,
        gpioe.pe15,
        &mut gpioe.moder,
        &mut gpioe.otyper,
    );

    status_led = leds.ld3;

}

fn lights_on() {
    status_led.on().ok();
}

fn lights_off() {
    status_led.off().ok()
}


 