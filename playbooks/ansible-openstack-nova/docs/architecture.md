# OpenStack Deployment Architecture

This document describes the architecture of the OpenStack deployment implemented by this Ansible playbook.

## Overview

This deployment follows the standard OpenStack architecture with a controller node and compute nodes. The controller node hosts all the core services, while compute nodes run the hypervisor and related services.

## Node Roles

### Controller Node

The controller node runs the following services:

1. **Identity Service (Keystone)**
   - Provides authentication and authorization for all OpenStack services
   - Manages users, projects, roles, and service catalogs
   - Uses Apache HTTP server with mod_wsgi to serve the API

2. **Image Service (Glance)**
   - Stores and retrieves virtual machine images
   - Supports multiple storage backends
   - Integrates with Keystone for authentication

3. **Compute Service (Nova)**
   - Controller components:
     - nova-api: REST API interface
     - nova-scheduler: Decides which host to run instances on
     - nova-conductor: Mediates interactions between nova-compute and database
     - nova-novncproxy: Provides VNC access to instances

4. **Messaging Queue (RabbitMQ)**
   - Provides communication between OpenStack services
   - Implements AMQP protocol for reliable messaging

5. **Database (MariaDB)**
   - Stores data for all OpenStack services
   - Uses MySQL-compatible database engine

### Compute Nodes

Compute nodes run the following services:

1. **Compute Service (Nova)**
   - nova-compute: Manages virtual machines through hypervisor APIs
   - nova-libvirt: Libvirt driver for managing KVM/QEMU instances

2. **Networking (Open vSwitch)**
   - Provides virtual networking capabilities
   - Manages virtual switches, bridges, and VLANs

## Service Interactions

### Authentication Flow

1. User requests authentication through Keystone
2. Keystone validates credentials and returns authentication token
3. User includes token in subsequent requests to other services
4. Services validate token with Keystone before processing requests

### Instance Creation Flow

1. User sends instance creation request to Nova API
2. Nova API validates request and forwards to Nova Conductor
3. Nova Conductor queries Nova Scheduler for appropriate compute node
4. Nova Scheduler selects compute node based on available resources
5. Nova Conductor instructs selected Nova Compute to create instance
6. Nova Compute uses Glance to retrieve image
7. Nova Compute uses Neutron for network configuration
8. Nova Compute uses Cinder for block storage (if requested)
9. Instance is created and started on compute node

### Database Access

All services access the MariaDB database:
- Keystone stores user, project, and service catalog data
- Glance stores image metadata
- Nova stores instance metadata and scheduling information
- Neutron stores network configuration data

Services use SQLAlchemy ORM for database access with connection pooling.

## Security Considerations

### User Permissions

Each OpenStack service runs under its own dedicated system user:
- Keystone runs as the `keystone` user
- Glance runs as the `glance` user
- Nova runs as the `nova` user
- Neutron runs as the `neutron` user

This provides process isolation and limits the impact of potential security breaches.

### Network Security

- Services communicate over internal network with encrypted connections where possible
- API endpoints are protected by Keystone authentication
- Database connections use secure authentication mechanisms

### Data Protection

- Fernet tokens are used for authentication (no persistence required)
- Credentials are encrypted using credential encryption keys
- Database connections are secured with strong passwords

## High Availability Considerations

This deployment is designed for a single-node setup for development and testing. For production environments, consider:

1. **Database replication** for high availability
2. **Load balancers** for API services
3. **Multiple controller nodes** with clustering
4. **Multiple compute nodes** for workload distribution
5. **Redundant messaging queues** for reliability

## Deployment Process

The Ansible playbooks deploy services in the following order:

1. Common configuration (networking, repositories)
2. Database (MariaDB)
3. Messaging queue (RabbitMQ)
4. Identity service (Keystone)
5. Image service (Glance)
6. Compute service (Nova)
7. Validation and testing

Each service is configured to start automatically and integrate with the others through the shared messaging queue and database.