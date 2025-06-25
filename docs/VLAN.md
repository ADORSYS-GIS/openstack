# Understanding VLANs and Their Operation

VLANs help us partition a LAN into smaller virtual networks for security
purposes. This allows us to have different logically distinct virtual networks
rather than having many physical small LANs.

Computers on the same network (LAN) communicate either through wireless access
points (AP) or through ethernet cables. All computers on a LAN are connected to
the same network switch.

## Types of VLANs

There are two types of VLANs:

- **Port-Based VLAN**: A VLAN is assigned to a particular port, and any machine
  connected to that port automatically joins that VLAN
- **User-Based or Dynamic VLAN**: VLANs are assigned based on user
  authentication or other dynamic criteria

## Network Architecture

```mermaid
flowchart TD
    subgraph "Physical Network Infrastructure"
        SW["Switch"]
    end
    
    subgraph "VLAN 10 (Marketing)"
        PC1["Computer 1\nIP address: 192.168.10.2\nVLAN 10"]
        PC2["Computer 2\nIP address: 192.168.10.3\nVLAN 10"]
    end
    
    subgraph "VLAN 20 (Engineering)"
        PC3["Computer 3\nIP address: 192.168.20.2\nVLAN 20"]
        PC4["Computer 4\nIP address: 192.168.20.3\nVLAN 20"]
    end
    
    subgraph "VLAN 30 (Finance)"
        PC5["Computer 5\nIP address: 192.168.30.2\nVLAN 30"]
        PC6["Computer 6\nIP address: 192.168.30.3\nVLAN 30"]
    end
    
    SW --- PC1
    SW --- PC2
    SW --- PC3
    SW --- PC4
    SW --- PC5
    SW --- PC6
    
    RT["Router\n(Inter-VLAN Routing)"]
    SW --- RT
    
    PC1 <--> PC2
    PC3 <--> PC4
    PC5 <--> PC6
    
    PC1 <-.-> |"Traffic Isolated\nUnless Routed"| PC3
    PC3 <-.-> |"Traffic Isolated\nUnless Routed"| PC5
    PC5 <-.-> |"Traffic Isolated\nUnless Routed"| PC1
    
    classDef vlan10 fill:#ffcccc,stroke:#ff0000
    classDef vlan20 fill:#ccffcc,stroke:#00ff00
    classDef vlan30 fill:#ccccff,stroke:#0000ff
    classDef network fill:#f9f9f9,stroke:#666666
    classDef router fill:#ffffcc,stroke:#ffcc00
    
    class PC1,PC2 vlan10
    class PC3,PC4 vlan20
    class PC5,PC6 vlan30
    class SW network
    class RT router
```
