# Foundations — BlueHarbor

## Step 1 — On-premises

### 1. Six layers

Building and facilities
BlueHarbor
Network
BlueHarbor
Servers and physical storage
BlueHarbor
Operating systems
BlueHarbor
Applications
BlueHarbor
Data
BlueHarbor
BlueHarbor is responsible for its on-premises environment. The case mentions that a contractor installed the domain controller, but does not specify who currently administers each layer.

2. Advantage and drawback
Advantage: BlueHarbor has direct control over its infrastructure and data.
Drawback: BlueHarbor is responsible for maintenance, security, equipment replacement and recovery.
Step 2 — Virtualisation
1. Current resource use
Each physical server has 8 CPU cores.

Directory
8 × 8%
0.64
6 GB
Files
8 × 15%
1.20
10 GB
Finance
8 × 20%
1.60
14 GB
Print
8 × 5%
0.40
3 GB
Web
8 × 10%
0.80
6 GB
Backup
8 × 12%
0.96
8 GB
Total
5.60 cores
47 GB
These CPU values represent average usage, not peak demand.

2. Number of hosts
Each new host has 16 cores and 128 GB of RAM. At a maximum utilisation of 70%:

CPU: 16 × 70% = 11.2 cores.
RAM: 128 × 70% = 89.6 GB.
The average demand of 5.6 cores and 47 GB fits on one host under these limits. This simplified calculation does not include hypervisor overhead or peak usage.

I would buy two hosts for resilience: if one fails, the other could run the workloads, provided it has sufficient capacity and the necessary storage and recovery arrangements are in place.

3. Benefits and risk
Benefit 1: fewer physical servers to maintain.
Benefit 2: resources can be shared between virtual machines.
Risk: if the single host fails, all six virtual machines can become unavailable.
Step 3 — Hypervisor type
Production hosts: Type 1, because it runs directly on hardware and is suited to managing production virtual machines.
Laptop for this course: Type 2, using VirtualBox on the existing host operating system.
Accountant's laptop: Type 2, because it can run an older Windows environment as a virtual machine without replacing the laptop's main operating system.
Step 4 — From on-premises to cloud
A virtualised data centre is not automatically a private cloud. It still needs cloud capabilities such as self-service provisioning, automation and resource management.

A public cloud provides access to provider-managed infrastructure on demand, with services that can be provisioned and scaled without BlueHarbor buying and maintaining the underlying hardware.

Step 5 — Deployment model
Active Directory
On-premises
Keeps the local directory close to the internal network and existing systems.
Finance application
On-premises
Keeps a sensitive internal application under BlueHarbor's direct control.
TrackIt website
Public cloud
Makes the customer-facing website accessible and allows the web tier to scale.
TrackIt shipment data
Public cloud
A managed database can support the cloud application; access and backups must be secured.
Off-site backups
Public cloud
Keeps a copy outside the server room, protected with encryption and access controls.
The resulting model is hybrid because BlueHarbor uses both on-premises infrastructure and public cloud services. The two parts need secure network connectivity and appropriate access controls.

Step 6 — Scalability
TrackIt normally receives 500 visits per hour. Ten times that is 5,000 visits per hour for two days.

Downtime during change
Resizing may require a restart, depending on the platform.
Copies can often be added without downtime if deployment and load balancing are configured correctly.
Maximum capacity
Limited by the largest available server.
Can increase by adding copies, subject to platform limits and other bottlenecks.
Cost after the peak
Reduce the server size to avoid continuing to pay for unused capacity.
Remove extra copies to reduce cost after the peak.
Application requirements
The application must be able to use additional CPU effectively.
The application must support multiple instances, shared or external session state, and load balancing.
The vCPU and copy counts do not by themselves guarantee that either option can handle the traffic: load testing is needed.

Choice for the web tier: scale out, because extra copies can be added for the peak and removed afterwards.

Choice for the database: start with vertical scaling, because it is simpler for a single database. Monitor CPU, memory and queries, and consider read replicas if read traffic becomes the bottleneck.