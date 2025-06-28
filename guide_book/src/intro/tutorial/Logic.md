### Tying it together

We now have integrated a handler that will signal us when the button is pressed, and an API for turning on/off the lights. Let's complete the obvious logic and turn on/off the lights in response to the button.

###### ButtonToLedService.rs
```rust
#![no_std]
#![no_main]

extern crate panic_itm;

use cortex_m_rt::entry;

use stm32f3_discovery::stm32f3xx_hal::prelude::*;
use stm32f3_discovery::stm32f3xx_hal::pac;
use stm32f3_discovery::wait_for_interrupt;
use stm32f3_discovery::stm32f3xx_hal::delay::Delay;

mod ButtonHandler; 
mod LedApi;


fn read_user_button() -> bool {
    USER_BUTTON_PRESSED.load(Ordering::SeqCst)
}

#[entry]
fn main() -> ! {

    lights_init()

    let mut delay = Delay::new(core_periphs.SYST, clocks);
    
    loop {
        // give system some breathing room for the interrupt to occur
        delay.delay_ms(50u16);

        // synchronize the light to the button state
        if read_user_button() {
            lights_on()
        } else {
            lights_off()
        }

    }
}
```