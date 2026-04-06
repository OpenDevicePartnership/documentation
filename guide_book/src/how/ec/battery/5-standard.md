# Building the component

Let's get started on building our battery implementation

## A Mock Battery

In our example, we will build the full functionality of our component in a standard local-computer development environment.

This allows us to begin development without worrying about hardware complications while still implementing nearly all of the system’s behavior. In the end, we will have a fully functional—albeit artificial—battery subsystem.

Once complete, our battery implementation is ready to be migrated, flashed and tested on target embedded hardware, where it should behave identically as a virtual, and/or able to be integrated to actual battery hardware with minor HAL layer implementations that replace our virtual layer here.

In our example case, our battery will remain virtual, with simulated physical behavior.
