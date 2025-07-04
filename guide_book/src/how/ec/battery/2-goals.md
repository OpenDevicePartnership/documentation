# Goals of the Battery Component Example

In this example we will be constructing a functioning battery component.

The battery itself will be a virtual battery - no hardware required - and the behavioral aspects of it will be simulated.
We will, however, discuss what one would do to implement actual battery hardware control in a HAL layer, which is the only 
fundamental difference between the virtual and real-world manifestations of this component.

In this example, we will:

- Define the Traits of the battery component as defined by the industry standard Smart Battery Specification (SBS)
- Identify the hardware actions that fulfill these traits
- Define the HAL traits to match these hardware actions
- Implement the HAL traits to hardware access (or define mocks for a virtual example)
- Wrap this simple Traits implementation into a Device for service insertion
- Provide the service layer and insert the device into it
- Test the end result with unit tests and simple executions
- Update the project for an embedded build and deploy onto hardware.