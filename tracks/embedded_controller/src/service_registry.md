# Embedded Controller Service Registration

Embedded Controller components and services in ODP are statically composed at build time but must be registered with the **service infrastructure** to become discoverable and operational during execution.

This registration model allows each **policy domain** (e.g. power, thermal, charging) to **own and manage the devices** associated with it.

---

## Registration Pattern

> **Pseudocode (concept only)**  
> The registration flow is: construct → init services → register.
>
> ```rust,ignore
> let battery = BatteryDevice::new(DeviceId(1));
> // ...
> // in an async task function
> embedded_services::init().await;
> embedded_services::power::policy::register_device(&battery).await.unwrap();
> ```
>
> This omits static allocation (`StaticCell`), executor wiring for async tasks, and controller setup, for clarity.

### Realistic skeleton (matches the sample projects)

Refer to the [Battery implementation example](../../guide/how/ec/battery/10-service_registry.html) or the [examples in the embedded-services repository](https://github.com/OpenDevicePartnership/embedded-services/blob/main/examples/std/src/bin/battery.rs#L474) for more concrete examples.

```rust
// statically allocate single ownership
static BATTERY: StaticCell<MockBatteryDevice> = StaticCell::new();

// Construct a device handle
let battery = BATTERY.init(MockBatteryDevice::new(DeviceId(1)));

// In an async context, initialize services once, then register the device
embedded_services::init().await;
embedded_services::power::policy::register_device(&battery).await.unwrap();

// Controller setup is covered in the next section.
```
_Semantics note_: In ODP, “Device” types are __handles__ to a single underlying component; the service runtime serializes access. Introducing the controller simply gives policy logic a dedicated handle to act on; it does not create a second owner of the hardware.

### Bringing in the Controller

``` rust
let controller = CONTROLLER.init(
    MockBatteryController::<&'static mut MockBattery>::new(battery.inner_battery())
);
```
The controller is given a handle to the inner `MockBattery` (`inner_battery()`), not a second owner of the hardware. All access is serialized through the service runtime.

### What Registration Enables
| Feature | Enabled by Registration |
|---------|------------------------|
| Message Routing | The `comms` system delivers events to services |
| Task Spawning | Services are polled and run by the executor |
| Feature Exposure | Subfeatures (e.g. _fuel_gauge_) declared via trait contracts |
| Test Visibility | Services and devices can be observed in tests |

```mermaid
flowchart TD
    A[Component<br/>_Implements Trait_] --> B[Device Wrapper]
    B --> C[Controller<br/>_Implements Service Trait_]
    C --> D[SERVICE_REGISTRY]
    D --> E[Policy Manager<br/>_via Comms_]
    D -->|_Provides_| F[Async Task Execution]

```
>__Figure: Service Registration and Runtime Execution__
>
> Devices are wrapped and managed by controllers. These are registered into the service registry, which exposes them to both the message dispatcher and the async runtime for polling and task orchestration.

## Message Dispatch and Service Binding
Once a controller is registered, the service registry allows the comms system to route incoming events to the correct service based on:
- The __device ID__
- The __message type__
- The controller's implementation of the `handle()` function (_as defined by ServiceTraits_)

When a message is emitted (e.g. `BatteryEvent::UpdateStatus`), the comms channel looks up the appropriate service and dispatches the message.

Where `ServiceTraits` represent the service traits that define a Controller action,
implementation may look something like this (in this case, `ServiceTraits` defines a function
named `handle`, and it calls upon a local function defined in the device implementation):
```rust
impl ServiceTraits for BatteryController {
    async fn handle(&mut self, msg: Message) -> Result<()> {
        match msg {
            Message::Battery(BatteryEvent::UpdateStatus) => {
                self.device.update().await
            }
            _ => Ok(()),
        }
    }
}
```
This provides a flexible pattern where __services are matched to message types__ through trait implementations and static dispatch. No dynamic routing or introspection is used — behavior is known at compile time.

### Static Composition, Dynamic Coordination
While all services and components are statically bound into the final binary:
- __Message routing and task polling occur dynamically__
- __Controllers only receive messages for devices they were registered to manage__
- __Multiple services can be registered independently and coexist without conflict__

This pattern supports:
- Easy testing with mocks or alternate HALs
- Additive subsystem design (battery, charger, thermal)
- Isolated debugging of service behavior