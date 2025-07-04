# Preparing the component for service insertion.

Here we bring in the first of the service layers.  This may mean adding `embedded-services` to the workspace as a submodule.
We wrap our component into a Device and prepare it for insertion into a service registry.

We discuss a little about the next step - service insertion - and that we will be creating a simplified registry for the purposes of this example, and we will construct that registry here.

We will also discuss and build the mock "comms" espi construction to allow messaging between the Controller and the Device

