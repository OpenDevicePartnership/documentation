# EC Services

The Embedded Controller is responsible for an increasing number of tasks that are meant to be always available, independent of the main CPU. The scope of these EC services often goes beyond hardware device concerns alone.
These services often need to be exposed to the Operating System and Application layers so that higher-level monitoring and control designs can interact to inspect conditions or configure operating parameters.

Conceptually, any number of services could be exposed to the Operating System in this way.  The Windows Operating System specifies a particular set of EC Services that it requires.

These Windows services are discussed in the [Embedded Controller Interface Specification](../../guide/specs/ec_interface/ec_interface.md)

Windows-specific management features such as the [Microsoft Power Thermal Framework (MPTF)](../../guide/how/ec/thermal/mptf/mptf.md) implementation notes are relevant to this discussion also.






