## Our first ODP-Style handler pair (with faked bus semantics)

The microcontrollers used for Embedded Controller purposes are not the same ones used
in the example resources referenced by the Rust Book, but if you've started there then
you may already have a STM32F3 microcontroller Discovery board and you may have even played with it to blink the LED lights or some other exercises.

Let's build on what we already know from experimenting with the STM32F3 exercises from the Rust Book.

We already know we can use the tooling setup we have to write code for the STM32F3 that will light one of its LED displays when the user button is pressed.  
Code to do exactly that can be found in [stm32f3-discovers/examples/button.rs](stm32f3-discovers/examples/button.rs) of the development board resources.

That code looks like this:

```rust
#![no_std]
#![no_main]

extern crate panic_itm;
use cortex_m_rt::entry;

use stm32f3_discovery::stm32f3xx_hal::delay::Delay;
use stm32f3_discovery::stm32f3xx_hal::prelude::*;
use stm32f3_discovery::stm32f3xx_hal::pac;

use stm32f3_discovery::button::UserButton;
use stm32f3_discovery::leds::Leds;
use stm32f3_discovery::switch_hal::{InputSwitch, OutputSwitch};

#[entry]
fn main() -> ! {
    let device_periphs = pac::Peripherals::take().unwrap();
    let mut reset_and_clock_control = device_periphs.RCC.constrain();

    let core_periphs = cortex_m::Peripherals::take().unwrap();
    let mut flash = device_periphs.FLASH.constrain();
    let clocks = reset_and_clock_control.cfgr.freeze(&mut flash.acr);
    let mut delay = Delay::new(core_periphs.SYST, clocks);

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
    let mut status_led = leds.ld3;

    // initialize user button
    let mut gpioa = device_periphs.GPIOA.split(&mut reset_and_clock_control.ahb);
    let button = UserButton::new(gpioa.pa0, &mut gpioa.moder, &mut gpioa.pupdr);

    loop {
        delay.delay_ms(50u16);

        match button.is_active() {
            Ok(true) => {
                status_led.on().ok();
            }
            Ok(false) => {
                status_led.off().ok();
            }
            Err(_) => {
                panic!("Failed to read button state");
            }
        }
    }
}
```

Of course, the STM32F3 is _not_ an EC and we certainly would have little use for flashing lights on one if it were, but the basic process and principles are the same, and since we already know how to flash the lights, we can use this as a good way to show how and why the ODP framework fits into the scheme.

Let's first posit that the LED and the user button are two separate peripheral components.  As such, we probably want two separate ODP handlers to address these, and then some business logic to tie them together.  Let's start with the user button.



