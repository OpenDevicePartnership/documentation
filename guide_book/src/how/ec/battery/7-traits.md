# Using the ODP repositories for defined Battery Traits
In the previous step we set up our project workspace so that we can import from the ODP framework. In this step we will define the traits that our mock battery will expose. 

# Implementing the defined traits
From the overview discussion you will recall that the SBS specification defines the Smart Battery with a series of functions that will return required data in expected ways.
Not surprisingly, then, we will find that the embedded-batteries crate we have imported defines these functions as traits to a SmartBattery trait.  If you are new to Rust, recall that if this were, say, C++ or Java, we would call this the SmartBattery _class_, or an _interface_.  These are _almost_ interchangeable terms, but there are differences.  See [this definition](https://doc.rust-lang.org/book/ch10-02-traits.html) for more detail on that.

If we look through the `embedded-batteries` repository, we will see the SmartBattery trait defines the same functions we saw in the specification (except for the optional proprietary manufacturer facilitations).

So our job now is to implement these functions with data that comes from our battery - our Mock Battery.

We'll start off our `mock_battery.rs` file with this:
```rust
use embedded_batteries_async::smart_battery::{
    SmartBattery, CapacityModeValue, CapacityModeSignedValue, BatteryModeFields,
    BatteryStatusFields, SpecificationInfoFields, ManufactureDate, ErrorType, 
    Error, ErrorKind
};

#[derive(Debug)]
pub enum MockBatteryError {}

impl core::fmt::Display for MockBatteryError {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        write!(f, "MockBatteryError")
    }
}

impl Error for MockBatteryError {
    fn kind(&self) -> ErrorKind {
        ErrorKind::Other
    }    
}

pub struct MockBattery;

impl ErrorType for MockBattery {
    type Error = MockBatteryError;
}

impl SmartBattery for MockBattery {
    async fn remaining_capacity_alarm(&mut self) -> Result<CapacityModeValue, Self::Error> {
        Ok(CapacityModeValue::MilliAmpUnsigned(0))
    }

    async fn set_remaining_capacity_alarm(&mut self, _val: CapacityModeValue) -> Result<(), Self::Error> {
        Ok(())
    }

    async fn remaining_time_alarm(&mut self) -> Result<u16, Self::Error> {
        Ok(0)
    }

    async fn set_remaining_time_alarm(&mut self, _val: u16) -> Result<(), Self::Error> {
        Ok(())
    }

    async fn battery_mode(&mut self) -> Result<BatteryModeFields, Self::Error> {
        Ok(BatteryModeFields::default())
    }

    async fn set_battery_mode(&mut self, _val: BatteryModeFields) -> Result<(), Self::Error> {
        Ok(())
    }

    async fn at_rate(&mut self) -> Result<CapacityModeSignedValue, Self::Error> {
        Ok(CapacityModeSignedValue::MilliAmpSigned(0))
    }

    async fn set_at_rate(&mut self, _val: CapacityModeSignedValue) -> Result<(), Self::Error> {
        Ok(())
    }

    async fn at_rate_time_to_full(&mut self) -> Result<u16, Self::Error> {
        Ok(0)
    }

    async fn at_rate_time_to_empty(&mut self) -> Result<u16, Self::Error> {
        Ok(0)
    }

    async fn at_rate_ok(&mut self) -> Result<bool, Self::Error> {
        Ok(true)
    }

    async fn temperature(&mut self) -> Result<u16, Self::Error> {
        Ok(2950) // 29.5°C in deciKelvin
    }

    async fn voltage(&mut self) -> Result<u16, Self::Error> {
        Ok(7500) // mV
    }

    async fn current(&mut self) -> Result<i16, Self::Error> {
        Ok(1500)
    }

    async fn average_current(&mut self) -> Result<i16, Self::Error> {
        Ok(1400)
    }

    async fn max_error(&mut self) -> Result<u8, Self::Error> {
        Ok(1)
    }

    async fn relative_state_of_charge(&mut self) -> Result<u8, Self::Error> {
        Ok(88)
    }

    async fn absolute_state_of_charge(&mut self) -> Result<u8, Self::Error> {
        Ok(85)
    }

    async fn remaining_capacity(&mut self) -> Result<CapacityModeValue, Self::Error> {
        Ok(CapacityModeValue::MilliAmpUnsigned(4200))
    }

    async fn full_charge_capacity(&mut self) -> Result<CapacityModeValue, Self::Error> {
        Ok(CapacityModeValue::MilliAmpUnsigned(4800))
    }

    async fn run_time_to_empty(&mut self) -> Result<u16, Self::Error> {
        Ok(60)
    }

    async fn average_time_to_empty(&mut self) -> Result<u16, Self::Error> {
        Ok(75)
    }

    async fn average_time_to_full(&mut self) -> Result<u16, Self::Error> {
        Ok(30)
    }

    async fn charging_current(&mut self) -> Result<u16, Self::Error> {
        Ok(2000)
    }

    async fn charging_voltage(&mut self) -> Result<u16, Self::Error> {
        Ok(8400)
    }

    async fn battery_status(&mut self) -> Result<BatteryStatusFields, Self::Error> {
        Ok(BatteryStatusFields::default())
    }

    async fn cycle_count(&mut self) -> Result<u16, Self::Error> {
        Ok(100)
    }

    async fn design_capacity(&mut self) -> Result<CapacityModeValue, Self::Error> {
        Ok(CapacityModeValue::MilliAmpUnsigned(5000))
    }

    async fn design_voltage(&mut self) -> Result<u16, Self::Error> {
        Ok(7800)
    }

    async fn specification_info(&mut self) -> Result<SpecificationInfoFields, Self::Error> {
        Ok(SpecificationInfoFields::default())
    }

    async fn manufacture_date(&mut self) -> Result<ManufactureDate, Self::Error> {
        let mut date = ManufactureDate::new();
        date.set_day(1);
        date.set_month(1);
        date.set_year(2025 - 1980); // must use offset from 1980

        Ok(date)
    }

    async fn serial_number(&mut self) -> Result<u16, Self::Error> {
        Ok(12345)
    }

    async fn manufacturer_name(&mut self, buf: &mut [u8]) -> Result<(), Self::Error> {
        let name = b"MockBatteryCorp\0"; // Null-terminated string
        buf[..name.len()].copy_from_slice(name);
        Ok(())
    }

    async fn device_name(&mut self, buf: &mut [u8]) -> Result<(), Self::Error> {
        let name = b"MB-4200\0";
        buf[..name.len()].copy_from_slice(name);
        Ok(())
    }

    async fn device_chemistry(&mut self, buf: &mut [u8]) -> Result<(), Self::Error> {
        let name = b"LION\0";   // Null-terminated 5-byte string
        buf[..name.len()].copy_from_slice(name);
        Ok(())
    }
}
```
Yes, that's a bit long, but it's not particularly complex.
We'll unpack what all this is in a moment.  For now, let's verify this Rust code is valid and that we've imported from the ODP repository properly.

Type
```
cargo build
```
at the project root.
This should build without error.

## What's in there
The code in `mock_battery.rs` starts out with a `use` statement that imports what we will need from the `embedded-batteries_async::smart_battery` crate.

The next section defines a simple custom error type for use in our mock battery implementation. This MockBatteryError enum currently has no variants — it serves as a placeholder that allows our code to conform to the expected error traits used by the broader embedded_batteries framework.

By implementing `core::fmt::Display`, we ensure that error messages can be printed in a readable form (here, just "MockBatteryError") while we are building and running from our local machine in a std environment. Then, by implementing the `embedded_batteries::smart_battery::Error` trait, we allow this error to be returned in contexts where the smart battery interface expects a well-formed error object. The `.kind()` method returns `ErrorKind::Other` to indicate a generic error category.

This scaffolding allows our mock implementation to slot into the service framework cleanly, even if the actual logic is still forthcoming.

Finally, we get to the SmartBattery implementation for our MockBattery.  As you might guess, this simply implements each of the functions of the trait as declared, by simply returning an arbitrary representative return value for each.  We'll make these values more meaningful in the next step, but for now, it's pretty minimalist.


