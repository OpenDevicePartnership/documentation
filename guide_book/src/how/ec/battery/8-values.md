# Battery values

In the previous step, we defined the traits of our mock battery.  In this step, we will begin to implement the service layer that defines the messaging between the battery and the controller controller service.

Before we implement the actual service, however, let's write a quick test/example to illustrate these values being extracted from our battery traits.

## Use `tokio` for a temporary async main
Before we write our test, we need to _temporarily_ make use of another imported crate: `tokio`.  This gives us an async main function that we can call from.  Since we are using the `embedded_batteries_async` variant to be compatible later with the `Controller` interface, we can use `tokio` just for now to give us a similar asynchronous context to work from without undue effort for this short test.

In your `mock_battery/Cargo.toml`, add this line to the `[dependencies]` section:
```toml
tokio = { version = "1.45", features = ["full"] }
```

We'll be taking that out later on once we are done with this first sanity test.

## Create main.rs file for mock_battery

We’ll verify our setup with a minimal `main.rs` that queries and prints battery values.

In your mock_battery project create `src/main.rs` with this content:

```rust
use mock_battery::mock_battery::MockBattery;
use embedded_batteries_async::smart_battery::SmartBattery;


#[tokio::main]
async fn main() {
    let mut battery = MockBattery;

    let voltage = battery.voltage().await.unwrap();
    let soc = battery.relative_state_of_charge().await.unwrap();
    let temp = battery.temperature().await.unwrap();

    println!("Voltage: {} mV", voltage);
    println!("State of Charge: {}%", soc);
    println!("Temperature: {} deci-K", temp);
}
```
and type `cargo run` to build and execute it.
After it builds and runs successfully, you should see output similar to this:
```
Voltage: 4200 mV
State of Charge: 100%
Temperature: 2982 deci-K
```
This test of course simply proves that we can call into our SmartBattery implementation and get the values out of it that we've defined there.

Note that you can execute `Cargo run` in this case both from either the `battery_project/mock_battery` or `battery_project` directories.  
As we continue with the integration, we will only be able to build and execute from the `battery_project` root, so you may want to get used to running from there.

We're going to replace this main.rs very shortly in an upcoming step, and this print to console behavior will be removed.  But for now it's a good sanity check of what you have built so far.
Later, we'll turn checks like this into meaningful unit tests.

We'll move ahead with forwarding this information up to the battery service controller,
but for now, pat yourself on the back, pour yourself a cup of coffee, and take a moment to review the pattern you have walked through:

- Identified the traits needed for the battery per spec as reflected in the `SmartBattery` trait imported from the ODP embedded-batteries repository
- Implemented a HAL layer to retrieve these values from the hardware (We conveniently skipped this part because this is a mock battery)
- Implemented the traits to return these values per the `SmartBattery` trait
- Created a simple sanity check to prove these values are available at runtime.

Next, we'll look at the ODP embedded-services repository and the battery-service support we find there.


