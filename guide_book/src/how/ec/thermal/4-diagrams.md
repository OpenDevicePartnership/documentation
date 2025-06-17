

# Thermal component Diagrams

_TODO: This will mirror similar content for Battery_

The construction of a component such as our thermal subsystem looks as follows.

```mermaid
flowchart TD
    A[Service<br><i>Service initiates query</i>]
    B[Thermal Subsystem Controller<br><i>Orchestrates component behavior</i>]
    C[Thermal Component Trait Interface<br><i>Defines the functional contract</i>]
    D[Thermal HAL Implementation<br><i>Implements trait using hardware-specific logic</i>]
    E[EC / Hardware Access<br><i>Performs actual I/O operations</i>]

    A --> B
    B --> C
    C --> D
    D --> E

    subgraph Service Layer
        A
    end

    subgraph Subsystem Layer
        B
    end

    subgraph Component Layer
        C
        D
    end

    subgraph Hardware Layer
        E
    end
```

When in operation, it conducts its operations in response to message events

_TODO: Will be similar to battery example diagram_

