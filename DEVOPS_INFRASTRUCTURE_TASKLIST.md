# DevOps & Infrastructure Task List
## National Infrastructure for Secure Federated Learning

**Document Version:** 1.0
**Date:** 2025-10-22
**Source:** FL_FLWR_OPS Operations Manual v1.0
**Author:** DevOps & CI/CD Specialist

---

## Table of Contents
1. [Phase 0: Prerequisites and Planning](#phase-0-prerequisites-and-planning)
2. [Phase 1: Base Infrastructure Setup](#phase-1-base-infrastructure-setup)
3. [Phase 2: Security Infrastructure](#phase-2-security-infrastructure)
4. [Phase 3: Core Services Deployment](#phase-3-core-services-deployment)
5. [Phase 4: Federated Learning Components](#phase-4-federated-learning-components)
6. [Phase 5: Monitoring and Alerting](#phase-5-monitoring-and-alerting)
7. [Phase 6: Client Deployment](#phase-6-client-deployment)
8. [Phase 7: Validation and Documentation](#phase-7-validation-and-documentation)

---

## Phase 0: Prerequisites and Planning

### TASK-000: Infrastructure Requirements Documentation
**Dependencies:** None
**Priority:** Critical
**Estimated Time:** 4 hours

**Implementation Steps:**
1. Document Nectar cloud allocation requirements
2. Define network segmentation requirements
3. Identify VM specifications (CPU, RAM, GPU, Storage)
4. Document security group requirements
5. Plan IP addressing scheme

**Deliverables:**
- Infrastructure requirements document
- Network topology diagram
- IP addressing plan
- VM sizing specifications

**Validation:**
- Review and approval from stakeholders
- Security team sign-off

---

### TASK-001: Environment Inventory
**Dependencies:** TASK-000
**Priority:** Critical
**Estimated Time:** 2 hours

**Implementation Steps:**
1. Create inventory of Test environment assets
2. Create inventory of UAT environment assets
3. Document external dependencies (Nectar, ARDC)
4. Create DNS requirements list
5. Document certificate requirements

**Configuration Files:**
- `/docs/environments/test_environment.yml`
- `/docs/environments/uat_environment.yml`
- `/docs/infrastructure/dns_requirements.md`

**Validation:**
```bash
# Verify environment documentation exists
ls -la /docs/environments/
cat /docs/environments/test_environment.yml
```

---

## Phase 1: Base Infrastructure Setup

### TASK-100: Nectar VM Provisioning - Server Network
**Dependencies:** TASK-001
**Priority:** Critical
**Estimated Time:** 4 hours

**Implementation Steps:**
1. Provision VPN Server VM
   - OS: Ubuntu 24.04 LTS
   - Network: Public + Internal interfaces
   - Resources: 2 vCPU, 4GB RAM, 20GB disk

2. Provision Nginx Reverse Proxy VM
   - OS: Ubuntu 24.04 LTS
   - Network: Public interface
   - Resources: 2 vCPU, 4GB RAM, 20GB disk

3. Provision Keycloak/IAM VM
   - OS: Ubuntu 24.04 LTS
   - Network: Internal network only
   - Resources: 4 vCPU, 8GB RAM, 40GB disk

4. Provision JupyterHub VM
   - OS: Ubuntu 24.04 LTS
   - Network: Internal network only
   - Resources: 4 vCPU, 16GB RAM, 100GB disk
   - Docker support required

5. Provision SuperLink VM
   - OS: Ubuntu 24.04 LTS
   - Network: Internal network only
   - Resources: 8 vCPU, 32GB RAM, 100GB disk
   - GPU: 1x NVIDIA GPU (for vertical FL)

6. Provision Monitoring Server VM
   - OS: Ubuntu 24.04 LTS
   - Network: Internal network only
   - Resources: 4 vCPU, 8GB RAM, 100GB disk

**Nectar Security Groups:**
Create security groups for:
- `sg-public-web` (ports 22, 443)
- `sg-vpn-public` (ports 443, 1194/UDP)
- `sg-internal-services` (internal network only)
- `sg-monitoring` (port 9100, 9400, 9090, 3000)

**Configuration Files:**
- `/infrastructure/nectar/security_groups.yml`
- `/infrastructure/nectar/vm_definitions.yml`

**Validation:**
```bash
# Verify VMs are accessible
ssh ubuntu@<vpn-server-ip>
ssh ubuntu@<nginx-server-ip>
ssh ubuntu@<keycloak-server-ip>
ssh ubuntu@<jupyterhub-server-ip>
ssh ubuntu@<superlink-server-ip>
ssh ubuntu@<monitoring-server-ip>

# Verify network connectivity
ping -c 4 <internal-ip>
```

---

### TASK-101: PostgreSQL Database Provisioning
**Dependencies:** TASK-100
**Priority:** Critical
**Estimated Time:** 2 hours

**Implementation Steps:**
1. Deploy PostgreSQL instance via Nectar Database service
   - Version: PostgreSQL 17
   - Network: Internal network only
   - Resources: As per Nectar recommendations

2. Configure firewall rules
   - Allow connections from Keycloak VM (port 5432)
   - Allow connections from Grafana VM (port 5432)
   - Deny all other connections

3. Configure backup schedule
   - Daily automated backups
   - 30-day retention policy

**Security Configuration:**
```bash
# Firewall rules to implement
Source: <keycloak-internal-ip>/32 -> Destination: <postgres-ip>:5432
Source: <monitoring-internal-ip>/32 -> Destination: <postgres-ip>:5432
```

**Validation:**
```bash
# Test connectivity from Keycloak VM
psql -h <postgres-ip> -U postgres -p 5432 -c "\l"

# Verify firewall rules
# From unauthorized host should fail
psql -h <postgres-ip> -U postgres -p 5432 -c "\l"
```

---

### TASK-102: Operating System Base Configuration
**Dependencies:** TASK-100
**Priority:** Critical
**Estimated Time:** 4 hours per VM

**Implementation Steps (per VM):**
1. Update system packages
   ```bash
   sudo apt update
   sudo apt upgrade -y
   sudo apt autoremove -y
   ```

2. Configure timezone and NTP
   ```bash
   sudo timedatectl set-timezone Australia/Brisbane
   sudo apt install -y systemd-timesyncd
   sudo timedatectl set-ntp true
   ```

3. Configure SSH hardening
   ```bash
   sudo vi /etc/ssh/sshd_config
   # PermitRootLogin no
   # PasswordAuthentication no
   # PubkeyAuthentication yes
   sudo systemctl restart sshd
   ```

4. Install base utilities
   ```bash
   sudo apt install -y curl wget vim git htop net-tools ca-certificates
   ```

5. Configure system limits
   ```bash
   sudo vi /etc/security/limits.conf
   # Add appropriate limits
   ```

**Configuration Files:**
- `/etc/ssh/sshd_config`
- `/etc/systemd/timesyncd.conf`
- `/etc/security/limits.conf`

**Validation:**
```bash
# Verify timezone
timedatectl

# Verify SSH config
sudo sshd -t

# Verify system updates
apt list --upgradable
```

---

### TASK-103: User and Group Management
**Dependencies:** TASK-102
**Priority:** Critical
**Estimated Time:** 1 hour per VM

**Implementation Steps:**
1. Create `fl_system` group on all servers
   ```bash
   sudo groupadd fl_system
   ```

2. Add admin user to `fl_system` group
   ```bash
   sudo usermod -a -G fl_system $USER
   ```

3. Create service accounts (on respective servers):

   **On Keycloak Server:**
   ```bash
   sudo useradd -r -s /bin/false keycloak
   sudo usermod -a -G fl_system keycloak
   ```

   **On JupyterHub Server:**
   ```bash
   sudo useradd -r -s /bin/false jupyterhub
   sudo usermod -a -G fl_system jupyterhub
   ```

   **On SuperLink Server:**
   ```bash
   sudo useradd -r -s /bin/false superlink
   sudo usermod -a -G fl_system superlink
   ```

   **On SuperNode Clients:**
   ```bash
   sudo useradd -r -s /bin/false supernode
   sudo usermod -a -G fl_system supernode
   ```

**Validation:**
```bash
# Verify groups
getent group fl_system

# Verify service accounts
id keycloak
id jupyterhub
id superlink
id supernode

# Verify no shell access
sudo -u keycloak whoami  # Should fail or show restricted shell
```

---

### TASK-104: Directory Structure Creation
**Dependencies:** TASK-103
**Priority:** High
**Estimated Time:** 30 minutes per VM

**Implementation Steps:**
1. Create configuration directories:
   ```bash
   # On all servers
   sudo mkdir -p /etc/ssl/certs
   sudo mkdir -p /etc/ssl/private

   # On FL servers
   sudo mkdir -p /etc/flwr/superlink/certs
   sudo mkdir -p /etc/flwr/supernode/certs

   # On JupyterHub server
   sudo mkdir -p /etc/jupyterhub/config

   # On Nginx server
   sudo mkdir -p /etc/nginx/conf.d

   # On VPN server
   sudo mkdir -p /etc/openvpn/server
   sudo mkdir -p /etc/openvpn/clientcerts
   ```

2. Create application directories:
   ```bash
   # Python environments
   sudo mkdir -p /opt/python
   sudo chgrp -R fl_system /opt/python
   sudo chmod -R g+w /opt/python

   # Flower components
   sudo mkdir -p /opt/flwr/superlink
   sudo mkdir -p /opt/flwr/supernode
   sudo chgrp -R fl_system /opt/flwr
   sudo chmod -R g+w /opt/flwr

   # JupyterHub
   sudo mkdir -p /opt/jupyterhub
   sudo chgrp -R fl_system /opt/jupyterhub
   sudo chmod -R g+w /opt/jupyterhub

   # Keycloak
   sudo mkdir -p /opt/keycloak
   sudo chgrp -R fl_system /opt/keycloak
   sudo chmod -R g+w /opt/keycloak
   ```

**Directory Structure Table:**
| Node Type | Path | Description | Permissions |
|-----------|------|-------------|-------------|
| All | /etc/ssl/certs | Trusted CA keys | root:root 755 |
| All | /etc/ssl/private | Private SSL keys | root:root 700 |
| SuperLink/Node | /etc/flwr/superlink | SuperLink config | root:fl_system 775 |
| SuperLink/Node | /etc/flwr/supernode | SuperNode config | root:fl_system 775 |
| JupyterHub | /etc/jupyterhub/config | JupyterHub config | root:fl_system 775 |
| Nginx | /etc/nginx/conf.d | Nginx virtual hosts | root:root 755 |
| VPN | /etc/openvpn | VPN configurations | root:root 755 |
| All | /opt/python | Python virtual envs | root:fl_system 775 |
| FL Servers | /opt/flwr | Flower components | root:fl_system 775 |
| JupyterHub | /opt/jupyterhub | JupyterHub runtime | root:fl_system 775 |
| Keycloak | /opt/keycloak | Keycloak runtime | root:fl_system 775 |

**Validation:**
```bash
# Verify directory structure
tree -L 3 /etc/flwr
tree -L 2 /opt

# Verify permissions
ls -la /opt/python
ls -la /opt/flwr
ls -la /etc/flwr
```

---

## Phase 2: Security Infrastructure

### TASK-200: Local Certificate Authority Setup
**Dependencies:** TASK-104
**Priority:** Critical
**Estimated Time:** 2 hours

**Implementation Steps:**
1. Install easy-rsa on CA server (can be Nginx or dedicated server)
   ```bash
   sudo apt install -y easy-rsa
   ```

2. Configure PKI variables
   ```bash
   cd /usr/share/easy-rsa
   sudo cp vars.example vars
   sudo vi vars
   ```

   **Configuration:**
   ```bash
   set_var EASYRSA_PKI "$PWD/pki"
   set_var EASYRSA_REQ_COUNTRY "AU"
   set_var EASYRSA_REQ_PROVINCE "Queensland"
   set_var EASYRSA_REQ_CITY "Brisbane"
   set_var EASYRSA_REQ_ORG "QCIF"
   set_var EASYRSA_REQ_EMAIL "ops@qcif.edu.au"
   set_var EASYRSA_REQ_OU "DAS"
   set_var EASYRSA_KEY_SIZE 2048
   ```

3. Initialize PKI and build CA
   ```bash
   cd /usr/share/easy-rsa
   sudo ./easyrsa init-pki
   sudo ./easyrsa build-ca
   # Enter and record CA password in password manager
   ```

4. Secure CA files
   ```bash
   sudo chmod 700 /usr/share/easy-rsa/pki/private
   sudo chmod 600 /usr/share/easy-rsa/pki/private/ca.key
   ```

**Configuration Files:**
- `/usr/share/easy-rsa/vars`
- `/usr/share/easy-rsa/pki/ca.crt` (public CA certificate)
- `/usr/share/easy-rsa/pki/private/ca.key` (private CA key - SECURE)

**Validation:**
```bash
# Verify CA certificate
openssl x509 -in /usr/share/easy-rsa/pki/ca.crt -text -noout

# Verify permissions
ls -la /usr/share/easy-rsa/pki/private/
```

**Documentation:**
- CA password location in password manager
- CA certificate distribution procedure
- Certificate renewal schedule (document expiry date)

---

### TASK-201: Trust CA Certificate on All Hosts
**Dependencies:** TASK-200
**Priority:** Critical
**Estimated Time:** 30 minutes per host

**Implementation Steps:**
1. Distribute CA certificate to all hosts
   ```bash
   # From CA server
   sudo cp /usr/share/easy-rsa/pki/ca.crt /tmp/local-ca.crt
   scp /tmp/local-ca.crt ubuntu@<target-host>:/tmp/
   ```

2. On each host, install CA certificate
   ```bash
   sudo apt install -y ca-certificates
   sudo cp /tmp/local-ca.crt /usr/local/share/ca-certificates/local-ca.crt
   sudo update-ca-certificates
   ```

3. Verify trust
   ```bash
   # Check CA is in trusted store
   ls /etc/ssl/certs/local-ca.pem
   ```

**Configuration Files:**
- `/usr/local/share/ca-certificates/local-ca.crt`
- `/etc/ssl/certs/local-ca.pem` (symlink created by update-ca-certificates)

**Validation:**
```bash
# Verify CA trust
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /usr/local/share/ca-certificates/local-ca.crt

# Test with openssl
echo | openssl s_client -connect <internal-host>:8443 -CAfile /etc/ssl/certs/ca-certificates.crt
```

---

### TASK-202: Generate Server Certificates
**Dependencies:** TASK-200
**Priority:** Critical
**Estimated Time:** 30 minutes per certificate

**Certificates Required:**
1. OpenVPN Server
2. SuperLink Server
3. Keycloak Server
4. JupyterHub Server

**Implementation Steps (per server):**
1. Create certificate configuration file
   ```bash
   cd /usr/share/easy-rsa
   sudo vi certificate-<servername>.conf
   ```

   **Example for SuperLink:**
   ```ini
   [req]
   default_bits = 4096
   prompt = no
   default_md = sha256
   req_extensions = req_ext
   distinguished_name = dn

   [dn]
   C = AU
   ST = QLD
   O = QCIF
   CN = superlink.internal

   [req_ext]
   subjectAltName = @alt_names

   [alt_names]
   DNS.1 = superlink
   DNS.2 = superlink.internal
   DNS.3 = superlink.fl.qcif.local
   IP.1 = ::1
   IP.2 = 127.0.0.1
   IP.3 = 10.x.x.x
   ```

2. Generate certificate signing request on target server
   ```bash
   # On target server
   sudo mkdir -p /etc/ssl/private
   sudo openssl genrsa -out /etc/ssl/private/<servername>.key 4096
   sudo openssl req -new \
     -key /etc/ssl/private/<servername>.key \
     -out /tmp/<servername>.csr \
     -config certificate-<servername>.conf
   ```

3. Transfer CSR to CA server
   ```bash
   scp /tmp/<servername>.csr ubuntu@<ca-server>:/tmp/
   ```

4. Sign certificate on CA server
   ```bash
   cd /usr/share/easy-rsa
   sudo cp /tmp/<servername>.csr temp/
   sudo ./easyrsa import-req temp/<servername>.csr <servername>
   sudo ./easyrsa sign-req server <servername>
   # Enter CA password
   ```

5. Transfer signed certificate back to target server
   ```bash
   # On CA server
   sudo cp /usr/share/easy-rsa/pki/issued/<servername>.crt /tmp/
   scp /tmp/<servername>.crt ubuntu@<target-server>:/tmp/
   ```

6. Install certificate on target server
   ```bash
   # On target server
   sudo mv /tmp/<servername>.crt /etc/ssl/certs/
   sudo chmod 644 /etc/ssl/certs/<servername>.crt
   sudo chmod 600 /etc/ssl/private/<servername>.key

   # Convert to PEM if needed
   sudo openssl x509 -in /etc/ssl/certs/<servername>.crt -out /etc/ssl/certs/<servername>.pem
   ```

**Configuration Files:**
- `/etc/ssl/certs/<servername>.crt` (or .pem)
- `/etc/ssl/private/<servername>.key`

**Validation:**
```bash
# Verify certificate
openssl x509 -in /etc/ssl/certs/<servername>.crt -text -noout

# Verify certificate chain
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/<servername>.crt

# Check certificate matches private key
openssl x509 -noout -modulus -in /etc/ssl/certs/<servername>.crt | openssl md5
openssl rsa -noout -modulus -in /etc/ssl/private/<servername>.key | openssl md5
# MD5 hashes should match
```

---

### TASK-203: Generate mTLS Certificates for SuperNodes
**Dependencies:** TASK-200
**Priority:** Critical
**Estimated Time:** 30 minutes per SuperNode

**Implementation Steps:**
1. On CA server, generate SuperNode key pairs
   ```bash
   # For each SuperNode (adjust index as needed)
   KEY_DIR=/usr/share/easy-rsa/pki/clients
   sudo mkdir -p $KEY_DIR

   for i in {1..4}; do
     sudo ssh-keygen -t ecdsa -b 384 -N "" \
       -f "${KEY_DIR}/client_credentials_$i" \
       -C ""
   done
   ```

2. Create CSV file of public keys for SuperLink
   ```bash
   KEY_DIR=/usr/share/easy-rsa/pki/clients
   CSV_FILE=/usr/share/easy-rsa/pki/client_public_keys.csv

   sudo bash -c "printf '%s' \"\$(cat \"${KEY_DIR}/client_credentials_1.pub\" | sed 's/.\$//')\" > $CSV_FILE"

   for ((i=2; i<=4; i++)); do
     sudo bash -c "printf ',%s' \"\$(sed 's/.\$//' < \"${KEY_DIR}/client_credentials_$i.pub\")\" >> $CSV_FILE"
   done

   sudo bash -c "printf '\n' >> $CSV_FILE"
   ```

3. Distribute keys to SuperLink
   ```bash
   # Copy CSV to SuperLink server
   sudo cp /usr/share/easy-rsa/pki/client_public_keys.csv /tmp/
   scp /tmp/client_public_keys.csv ubuntu@<superlink-server>:/tmp/

   # On SuperLink server
   sudo mkdir -p /etc/flwr/superlink/certs
   sudo mv /tmp/client_public_keys.csv /etc/flwr/superlink/certs/
   sudo chown root:fl_system /etc/flwr/superlink/certs/client_public_keys.csv
   sudo chmod 640 /etc/flwr/superlink/certs/client_public_keys.csv
   ```

4. Distribute key pairs to each SuperNode
   ```bash
   # For each SuperNode client
   CLIENT_ID=1

   sudo cp /usr/share/easy-rsa/pki/clients/client_credentials_${CLIENT_ID} /tmp/
   sudo cp /usr/share/easy-rsa/pki/clients/client_credentials_${CLIENT_ID}.pub /tmp/

   scp /tmp/client_credentials_${CLIENT_ID}* ubuntu@<supernode-${CLIENT_ID}>:/tmp/

   # On SuperNode
   sudo mkdir -p /etc/flwr/supernode/certs
   sudo mv /tmp/client_credentials_${CLIENT_ID} /etc/flwr/supernode/certs/
   sudo mv /tmp/client_credentials_${CLIENT_ID}.pub /etc/flwr/supernode/certs/
   sudo chown root:fl_system /etc/flwr/supernode/certs/client_credentials_${CLIENT_ID}*
   sudo chmod 600 /etc/flwr/supernode/certs/client_credentials_${CLIENT_ID}
   sudo chmod 644 /etc/flwr/supernode/certs/client_credentials_${CLIENT_ID}.pub
   ```

**Configuration Files:**
- SuperLink: `/etc/flwr/superlink/certs/client_public_keys.csv`
- SuperNode: `/etc/flwr/supernode/certs/client_credentials_N`
- SuperNode: `/etc/flwr/supernode/certs/client_credentials_N.pub`

**Validation:**
```bash
# On SuperLink - verify CSV format
cat /etc/flwr/superlink/certs/client_public_keys.csv

# On each SuperNode - verify key pair
ssh-keygen -l -f /etc/flwr/supernode/certs/client_credentials_${CLIENT_ID}
ssh-keygen -l -f /etc/flwr/supernode/certs/client_credentials_${CLIENT_ID}.pub
# Fingerprints should match
```

---

### TASK-204: VPN Server Configuration
**Dependencies:** TASK-202, TASK-203
**Priority:** Critical
**Estimated Time:** 3 hours

**Implementation Steps:**
1. Install OpenVPN
   ```bash
   sudo apt install -y openvpn
   ```

2. Generate VPN-specific keys
   ```bash
   cd /usr/share/easy-rsa
   sudo ./easyrsa --nopass build-server-full openvpnserver
   sudo ./easyrsa gen-dh
   sudo openvpn --genkey secret pki/private/ta.key
   ```

3. Copy VPN keys to configuration directory
   ```bash
   sudo cp /usr/share/easy-rsa/pki/ca.crt /etc/openvpn/server/
   sudo cp /usr/share/easy-rsa/pki/dh.pem /etc/openvpn/server/
   sudo cp /usr/share/easy-rsa/pki/issued/openvpnserver.crt /etc/openvpn/server/
   sudo cp /usr/share/easy-rsa/pki/private/openvpnserver.key /etc/openvpn/server/
   sudo cp /usr/share/easy-rsa/pki/private/ta.key /etc/openvpn/server/

   sudo chmod 600 /etc/openvpn/server/*.key
   sudo chmod 600 /etc/openvpn/server/ta.key
   ```

4. Create server configuration
   ```bash
   sudo vi /etc/openvpn/server/server.conf
   ```

   **Configuration:**
   ```
   port 1194
   proto udp
   dev tap

   server 192.168.99.0 255.255.255.0

   ca ca.crt
   cert openvpnserver.crt
   key openvpnserver.key
   dh dh.pem
   tls-auth ta.key 0

   # Push route to internal network
   push "route 10.255.0.0 255.255.0.0"

   persist-key
   persist-tun
   keepalive 10 60

   user nobody
   group nogroup

   daemon
   log-append /var/log/openvpn/openvpn.log

   verb 3
   ```

5. Enable IP forwarding
   ```bash
   sudo vi /etc/sysctl.conf
   # Uncomment: net.ipv4.ip_forward=1
   sudo sysctl -p
   ```

6. Configure iptables NAT
   ```bash
   # Assuming eth1 is internal network interface
   sudo iptables -t nat -A POSTROUTING -s 192.168.99.0/24 -o eth1 -j MASQUERADE

   # Save iptables rules
   sudo apt install -y iptables-persistent
   sudo netfilter-persistent save
   ```

7. Enable and start OpenVPN service
   ```bash
   sudo systemctl enable openvpn-server@server.service
   sudo systemctl start openvpn-server@server.service
   ```

**Configuration Files:**
- `/etc/openvpn/server/server.conf`
- `/etc/sysctl.conf`
- `/etc/iptables/rules.v4`

**Network Configuration:**
- VPN Subnet: 192.168.99.0/24
- Internal Network: 10.255.0.0/16 (adjust as needed)

**Validation:**
```bash
# Verify service status
sudo systemctl status openvpn-server@server.service

# Verify VPN interface
ip addr show tap0

# Verify IP forwarding
cat /proc/sys/net/ipv4/ip_forward
# Should output: 1

# Verify iptables rules
sudo iptables -t nat -L -n -v

# Check logs
sudo tail -f /var/log/openvpn/openvpn.log
```

---

### TASK-205: Generate VPN Client Configurations
**Dependencies:** TASK-204
**Priority:** Critical
**Estimated Time:** 1 hour per client

**Implementation Steps:**
1. Generate client certificates on CA server
   ```bash
   cd /usr/share/easy-rsa
   # Edit vars to set EASYRSA_REQ_EMAIL to empty
   sudo vi vars
   # set_var EASYRSA_REQ_EMAIL ""

   # Generate client certificate
   sudo ./easyrsa --nopass build-client-full client1
   ```

2. Prepare client certificate package
   ```bash
   sudo mkdir -p /etc/openvpn/clientcerts/client1
   sudo cp /usr/share/easy-rsa/pki/ca.crt /etc/openvpn/clientcerts/client1/
   sudo cp /usr/share/easy-rsa/pki/issued/client1.crt /etc/openvpn/clientcerts/client1/
   sudo cp /usr/share/easy-rsa/pki/private/client1.key /etc/openvpn/clientcerts/client1/
   sudo cp /usr/share/easy-rsa/pki/private/ta.key /etc/openvpn/clientcerts/client1/
   ```

3. Create client configuration file
   ```bash
   sudo vi /etc/openvpn/clientcerts/client1/client.conf
   ```

   **Configuration:**
   ```
   client
   proto udp
   remote <vpn-server-public-ip> 1194
   dev tap
   nobind

   remote-cert-tls server

   ca ca.crt
   cert client1.crt
   key client1.key
   tls-auth ta.key 1

   persist-key
   persist-tun
   keepalive 10 60

   verb 3
   ```

4. Create distribution package
   ```bash
   cd /etc/openvpn/clientcerts
   sudo tar -czf client1-vpn-config.tar.gz client1/
   ```

**Configuration Files:**
- `/etc/openvpn/clientcerts/client1/ca.crt`
- `/etc/openvpn/clientcerts/client1/client1.crt`
- `/etc/openvpn/clientcerts/client1/client1.key`
- `/etc/openvpn/clientcerts/client1/ta.key`
- `/etc/openvpn/clientcerts/client1/client.conf`

**Distribution:**
Securely transfer `client1-vpn-config.tar.gz` to client organization via:
- Encrypted email
- Secure file transfer
- In-person handoff

**Validation:**
```bash
# Test client configuration locally (if possible)
sudo openvpn --config /etc/openvpn/clientcerts/client1/client.conf

# Verify connectivity
ping -c 4 <internal-network-host>
```

---

## Phase 3: Core Services Deployment

### TASK-300: PostgreSQL Database Setup for Keycloak
**Dependencies:** TASK-101
**Priority:** Critical
**Estimated Time:** 1 hour

**Implementation Steps:**
1. Connect to PostgreSQL server
   ```bash
   sudo -u postgres psql -h <postgres-host> -p 5432
   ```

2. Create Keycloak database role
   ```sql
   CREATE ROLE keycloak WITH
     LOGIN
     NOSUPERUSER
     INHERIT
     CREATEDB
     CREATEROLE
     PASSWORD 'STRONG_PASSWORD_HERE';
   ```

3. Create Keycloak database
   ```sql
   DROP DATABASE IF EXISTS keycloakdb_server;

   CREATE DATABASE keycloakdb_server
     WITH
     OWNER = keycloak
     ENCODING = 'UTF8'
     LC_COLLATE = 'en_AU.UTF-8'
     LC_CTYPE = 'en_AU.UTF-8'
     LOCALE_PROVIDER = 'libc'
     TABLESPACE = pg_default
     CONNECTION LIMIT = -1
     IS_TEMPLATE = False;
   ```

4. Create Keycloak schema
   ```bash
   sudo -u postgres psql -h <postgres-host> -p 5432 -d keycloakdb_server
   ```

   ```sql
   CREATE SCHEMA IF NOT EXISTS keycloak
     AUTHORIZATION keycloak;
   ```

5. Test connection
   ```bash
   # From Keycloak server
   psql -h <postgres-host> -U keycloak -d keycloakdb_server -p 5432 -c "\dn"
   # Should list schemas including 'keycloak'
   ```

**Credentials Storage:**
- Store database credentials in secure password manager
- Document connection string format

**Connection String:**
```
jdbc:postgresql://<postgres-host>:5432/keycloakdb_server?options=-csearch_path=keycloak
```

**Validation:**
```bash
# Verify database exists
psql -h <postgres-host> -U keycloak -d keycloakdb_server -p 5432 -c "\l"

# Verify schema exists
psql -h <postgres-host> -U keycloak -d keycloakdb_server -p 5432 -c "\dn"

# Test write permission
psql -h <postgres-host> -U keycloak -d keycloakdb_server -p 5432 -c "CREATE TABLE keycloak.test (id INT); DROP TABLE keycloak.test;"
```

---

### TASK-301: Keycloak Installation and Configuration
**Dependencies:** TASK-300, TASK-202
**Priority:** Critical
**Estimated Time:** 4 hours

**Implementation Steps:**
1. Install Java OpenJDK
   ```bash
   sudo apt install -y openjdk-21-jre openjdk-21-jdk
   java --version
   ```

2. Download and extract Keycloak
   ```bash
   cd /tmp
   wget https://github.com/keycloak/keycloak/releases/download/26.3.0/keycloak-26.3.0.zip

   sudo -u keycloak cp keycloak-26.3.0.zip /opt/keycloak/
   cd /opt/keycloak
   sudo -u keycloak unzip keycloak-26.3.0.zip
   ```

3. Configure Keycloak database connection
   ```bash
   cd /opt/keycloak/keycloak-26.3.0
   sudo -u keycloak vi conf/keycloak.conf
   ```

   **Configuration:**
   ```properties
   # Database
   db=postgres
   db-username=keycloak
   db-password=STRONG_PASSWORD_HERE
   db-url=jdbc:postgresql://<postgres-host>:5432/keycloakdb_server?currentSchema=keycloak

   # HTTPS
   https-certificate-file=${kc.home.dir}/conf/certs/server.pem
   https-certificate-key-file=${kc.home.dir}/conf/certs/serverkey.pem
   https-port=8443

   # Proxy
   proxy=reencrypt

   # Hostname
   hostname=keycloak.internal
   ```

4. Copy SSL certificates
   ```bash
   sudo mkdir -p /opt/keycloak/keycloak-26.3.0/conf/certs
   sudo cp /etc/ssl/certs/keycloak.crt /opt/keycloak/keycloak-26.3.0/conf/certs/
   sudo cp /etc/ssl/private/keycloak.key /opt/keycloak/keycloak-26.3.0/conf/certs/

   # Convert to PEM format
   cd /opt/keycloak/keycloak-26.3.0/conf/certs/
   sudo openssl x509 -in keycloak.crt -out server.pem
   sudo openssl rsa -in keycloak.key -text > serverkey.pem

   sudo chown keycloak:fl_system /opt/keycloak/keycloak-26.3.0/conf/certs/*
   sudo chmod 640 /opt/keycloak/keycloak-26.3.0/conf/certs/*
   ```

5. Build optimized Keycloak
   ```bash
   cd /opt/keycloak/keycloak-26.3.0
   sudo -u keycloak bin/kc.sh build
   ```

6. Create systemd service unit
   ```bash
   sudo vi /opt/keycloak/run_keycloak.sh
   ```

   **Script:**
   ```bash
   #!/bin/bash
   export KEYCLOAK_VERSION="keycloak-26.3.0"
   cd /opt/keycloak/$KEYCLOAK_VERSION
   sh bin/kc.sh start --optimized
   ```

   ```bash
   sudo chmod +x /opt/keycloak/run_keycloak.sh
   ```

   ```bash
   sudo vi /opt/keycloak/keycloak.service
   ```

   **Service Unit:**
   ```ini
   [Unit]
   Description=Keycloak Server
   After=network.target

   [Install]
   Alias=keycloak.service
   WantedBy=multi-user.target

   [Service]
   User=keycloak
   Group=fl_system
   Type=simple
   WorkingDirectory=/opt/keycloak/
   ExecStart=bash run_keycloak.sh
   Restart=always
   RestartSec=5
   ```

7. Enable and start Keycloak
   ```bash
   sudo cp /opt/keycloak/keycloak.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable keycloak.service
   sudo systemctl start keycloak.service
   ```

**Configuration Files:**
- `/opt/keycloak/keycloak-26.3.0/conf/keycloak.conf`
- `/opt/keycloak/run_keycloak.sh`
- `/etc/systemd/system/keycloak.service`

**Validation:**
```bash
# Check service status
sudo systemctl status keycloak.service

# Check logs
sudo journalctl -u keycloak.service -f

# Verify HTTPS endpoint
curl -k https://keycloak.internal:8443/

# Test database connection
psql -h <postgres-host> -U keycloak -d keycloakdb_server -c "SELECT schemaname,tablename FROM pg_tables WHERE schemaname='keycloak' LIMIT 5;"
# Should show Keycloak tables
```

---

### TASK-302: Keycloak Realm and Client Configuration
**Dependencies:** TASK-301
**Priority:** Critical
**Estimated Time:** 2 hours

**Implementation Steps:**
1. Access Keycloak admin console
   - URL: `https://keycloak.internal:8443/`
   - Create initial admin user (first login)

2. Create new realm: `flowerfl`
   - Navigate to: Master dropdown > Create Realm
   - Name: `flowerfl`
   - Enabled: ON

3. Create client: `flower_auth_client`
   - Navigate to: Clients > Create client
   - Client ID: `flower_auth_client`
   - Client type: OpenID Connect
   - Client authentication: ON
   - Save and note client secret

4. Configure client settings
   - Valid redirect URIs:
     - `https://flhub.yourdomain.org.au/*`
     - `https://superlink.yourdomain.org.au/*`
   - Web origins: `+`

   **Capability config:**
   - Client authentication: ON
   - Authorization: ON
   - Authentication flow:
     - Standard flow: ON
     - Implicit flow: ON
     - Direct access grants: ON
     - OAuth 2.0 Device Authorization Grant: ON

5. Create realm roles
   - Navigate to: Realm roles > Create role
   - Create roles:
     - `jupyter_admin`
     - `jupyter_user`
     - `superlink_user`

6. Create groups
   - Navigate to: Groups > Create group
   - Create groups:
     - `jupyter_admins` (assign roles: jupyter_admin, superlink_user)
     - `jupyter_users` (assign roles: jupyter_user, superlink_user)

7. Create test users
   - Navigate to: Users > Add user
   - Create test users and assign to groups
   - Set passwords (Credentials tab)

**Configuration Documentation:**
- Client ID: `flower_auth_client`
- Client Secret: `<store in password manager>`
- Realm: `flowerfl`
- Auth URL: `https://keycloak.yourdomain.org.au/realms/flowerfl/protocol/openid-connect/auth`
- Token URL: `https://keycloak.internal:8443/realms/flowerfl/protocol/openid-connect/token`
- UserInfo URL: `https://keycloak.internal:8443/realms/flowerfl/protocol/openid-connect/userinfo`

**Validation:**
```bash
# Test OIDC discovery endpoint
curl -k https://keycloak.internal:8443/realms/flowerfl/.well-known/openid-configuration | jq

# Test client credentials
curl -k -X POST https://keycloak.internal:8443/realms/flowerfl/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=flower_auth_client" \
  -d "client_secret=<client-secret>" | jq
```

---

### TASK-303: Nginx Reverse Proxy Setup
**Dependencies:** TASK-202
**Priority:** Critical
**Estimated Time:** 2 hours

**Implementation Steps:**
1. Install Nginx
   ```bash
   sudo apt install -y nginx
   ```

2. Obtain public SSL certificate (Let's Encrypt)
   ```bash
   sudo apt install -y certbot python3-certbot-nginx

   # Obtain wildcard certificate
   sudo certbot certonly --manual --preferred-challenges dns \
     -d "*.yourdomain.org.au" \
     -d "yourdomain.org.au"

   # Follow DNS challenge instructions
   # Certificates will be in: /etc/letsencrypt/live/yourdomain.org.au/
   ```

3. Configure Nginx reverse proxy
   ```bash
   sudo vi /etc/nginx/conf.d/reverse-proxy.conf
   ```

   **Configuration:**
   ```nginx
   # Keycloak proxy
   server {
       listen 443 ssl;
       server_name keycloak.yourdomain.org.au;

       ssl_certificate /etc/letsencrypt/live/yourdomain.org.au/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/yourdomain.org.au/privkey.pem;

       access_log /var/log/nginx/keycloak.access.log;
       error_log /var/log/nginx/keycloak.error.log;

       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
       proxy_redirect off;
       server_name_in_redirect off;

       location / {
           proxy_pass https://keycloak.internal:8443/;
       }
   }

   # JupyterHub proxy
   server {
       listen 443 ssl;
       server_name flhub.yourdomain.org.au;

       ssl_certificate /etc/letsencrypt/live/yourdomain.org.au/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/yourdomain.org.au/privkey.pem;

       access_log /var/log/nginx/flhub.access.log;
       error_log /var/log/nginx/flhub.error.log;

       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
       proxy_redirect off;
       server_name_in_redirect off;

       # WebSocket support for JupyterHub
       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";

       location / {
           proxy_pass https://jupyterhub.internal:8000/;
       }
   }
   ```

4. Test and reload Nginx
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   sudo systemctl enable nginx
   ```

5. Configure firewall for Nginx
   ```bash
   sudo ufw allow 'Nginx Full'
   sudo ufw enable
   ```

**Configuration Files:**
- `/etc/nginx/conf.d/reverse-proxy.conf`
- `/etc/letsencrypt/live/yourdomain.org.au/fullchain.pem`
- `/etc/letsencrypt/live/yourdomain.org.au/privkey.pem`

**Validation:**
```bash
# Test Nginx config
sudo nginx -t

# Check service status
sudo systemctl status nginx

# Test HTTP redirects
curl -I http://keycloak.yourdomain.org.au
curl -I https://keycloak.yourdomain.org.au
curl -I https://flhub.yourdomain.org.au

# Verify SSL certificate
openssl s_client -connect keycloak.yourdomain.org.au:443 -servername keycloak.yourdomain.org.au
```

---

### TASK-304: Docker Installation on JupyterHub Server
**Dependencies:** TASK-102
**Priority:** High
**Estimated Time:** 1 hour

**Implementation Steps:**
1. Install Docker
   ```bash
   sudo apt install -y docker.io
   ```

2. Create docker group and add users
   ```bash
   sudo groupadd docker  # May already exist
   sudo usermod -aG docker $USER
   sudo usermod -aG docker jupyterhub
   ```

3. Enable Docker service
   ```bash
   sudo systemctl enable docker
   sudo systemctl start docker
   ```

4. Test Docker installation
   ```bash
   # Logout and login for group membership
   # Then test:
   docker run hello-world
   ```

5. Pull JupyterHub notebook images
   ```bash
   docker pull quay.io/jupyter/datascience-notebook:latest
   docker pull quay.io/jupyter/tensorflow-notebook:latest
   docker pull quay.io/jupyter/pytorch-notebook:latest
   ```

**Configuration Files:**
- `/etc/docker/daemon.json` (for custom Docker config if needed)

**Validation:**
```bash
# Verify Docker version
docker --version

# Verify service status
sudo systemctl status docker

# Verify images
docker images

# Test as jupyterhub user
sudo -u jupyterhub docker ps
```

---

### TASK-305: Python Virtual Environments Setup
**Dependencies:** TASK-104
**Priority:** High
**Estimated Time:** 1 hour per environment

**Environments Required:**
1. `/opt/python/jupyter_env` (JupyterHub server)
2. `/opt/python/flower_env` (SuperLink server)
3. `/opt/python/flower_env` (SuperNode clients)

**Implementation Steps (JupyterHub):**
1. Create virtual environment
   ```bash
   cd /opt/python
   python3 -m venv jupyter_env
   ```

2. Activate and install dependencies
   ```bash
   source /opt/python/jupyter_env/bin/activate
   pip install --upgrade pip
   pip install jupyterhub oauthenticator dockerspawner
   ```

3. Install Node.js for configurable-http-proxy
   ```bash
   sudo apt install -y npm
   sudo npm install -g configurable-http-proxy
   ```

**Implementation Steps (Flower - SuperLink/SuperNode):**
1. Create virtual environment
   ```bash
   cd /opt/python
   python3 -m venv flower_env
   ```

2. Activate and install dependencies
   ```bash
   source /opt/python/flower_env/bin/activate
   pip install --upgrade pip
   pip install --timeout=60 flwr flwr-datasets[vision]
   pip install --timeout=60 tensorflow==2.17
   pip install --timeout=60 tensorflow-probability==0.24.0
   pip install --timeout=60 torch==2.2
   pip install --timeout=60 torchvision==0.17
   pip install --timeout=60 torchaudio==2.2
   pip install --timeout=60 pandas scipy scikit-learn seaborn matplotlib
   ```

**Configuration Files:**
- `/opt/python/jupyter_env/pyvenv.cfg`
- `/opt/python/flower_env/pyvenv.cfg`

**Validation:**
```bash
# JupyterHub environment
source /opt/python/jupyter_env/bin/activate
which python
pip list | grep jupyterhub
which configurable-http-proxy

# Flower environment
source /opt/python/flower_env/bin/activate
which python
pip list | grep flwr
python -c "import tensorflow as tf; print(tf.__version__)"
python -c "import torch; print(torch.__version__)"
```

---

### TASK-306: JupyterHub Configuration
**Dependencies:** TASK-304, TASK-305, TASK-302
**Priority:** High
**Estimated Time:** 3 hours

**Implementation Steps:**
1. Generate JupyterHub configuration
   ```bash
   mkdir -p /opt/jupyterhub
   cd /opt/jupyterhub
   source /opt/python/jupyter_env/bin/activate
   jupyterhub --generate-config
   ```

2. Move config to standard location
   ```bash
   sudo mkdir -p /etc/jupyterhub/config
   sudo mv jupyterhub_config.py /etc/jupyterhub/config/
   ```

3. Configure JupyterHub
   ```bash
   sudo vi /etc/jupyterhub/config/jupyterhub_config.py
   ```

   **Key Configurations:**
   ```python
   import os

   # OAuth configuration with Keycloak
   c.JupyterHub.authenticator_class = "generic-oauth"

   # OAuth2 application info
   c.GenericOAuthenticator.client_id = "flower_auth_client"
   c.GenericOAuthenticator.client_secret = "<client-secret-from-keycloak>"

   # Identity provider info
   c.GenericOAuthenticator.authorize_url = "https://keycloak.yourdomain.org.au/realms/flowerfl/protocol/openid-connect/auth"
   c.GenericOAuthenticator.token_url = "https://keycloak.internal:8443/realms/flowerfl/protocol/openid-connect/token"
   c.GenericOAuthenticator.userdata_url = "https://keycloak.internal:8443/realms/flowerfl/protocol/openid-connect/userinfo"

   # User info scope
   c.GenericOAuthenticator.manage_groups = True
   c.GenericOAuthenticator.scope = ["openid", "email", "groups"]
   c.GenericOAuthenticator.username_claim = "preferred_username"
   c.GenericOAuthenticator.auth_state_groups_key = "oauth_user.groups"

   # Authorization
   c.GenericOAuthenticator.allowed_groups = {"jupyter_users"}
   c.GenericOAuthenticator.admin_groups = {"jupyter_admins"}

   # Network config
   c.JupyterHub.bind_url = 'https://jupyterhub.internal:8000'
   c.JupyterHub.hub_connect_ip = '<jupyterhub-internal-ip>'

   # Docker spawner
   c.JupyterHub.concurrent_spawn_limit = 20
   c.JupyterHub.spawner_class = 'dockerspawner.DockerSpawner'

   # Notebook options
   c.DockerSpawner.image = "quay.io/jupyter/datascience-notebook"

   def allowed_images(self):
       return [
           "quay.io/jupyter/datascience-notebook",
           "quay.io/jupyter/tensorflow-notebook",
           "quay.io/jupyter/pytorch-notebook"
       ]
   c.DockerSpawner.allowed_images = allowed_images

   # Mount points
   notebook_dir = os.environ.get('DOCKER_NOTEBOOK_DIR') or '/home/jovyan/work'
   c.DockerSpawner.notebook_dir = notebook_dir

   c.DockerSpawner.mounts = [
       {
           'source': '/home/jupyterhub/workspace/{username}',
           'target': notebook_dir,
           'type': 'bind'
       }
   ]

   def pre_spawn(spawner):
       username = spawner.user.name
       mounts = spawner.mounts
       for mount_path in mounts:
           src_path = mount_path['source'].replace("{username}", spawner.escaped_name)
           if not os.path.exists(src_path):
               os.makedirs(src_path, exist_ok=True)

   c.DockerSpawner.pre_spawn_hook = pre_spawn

   # SSL certificates
   c.JupyterHub.ssl_cert = '/etc/ssl/certs/jupyterhub.pem'
   c.JupyterHub.ssl_key = '/etc/ssl/private/jupyterhub.key'
   ```

4. Create environment configuration
   ```bash
   sudo vi /etc/jupyterhub/jupyterhub.conf
   ```

   **Configuration:**
   ```bash
   # the config file to load.
   jupyter_config_file=jupyterhub_config.py
   ```

5. Create systemd service
   ```bash
   sudo vi /opt/jupyterhub/run_jupyterhub.sh
   ```

   **Script:**
   ```bash
   #!/bin/bash
   export PYTHONENV=/opt/python/jupyter_env/
   source $PYTHONENV/bin/activate

   cd /opt/jupyterhub
   export TF_FORCE_GPU_ALLOW_GROWTH=true
   export PYTHONPATH=/opt/jupyterhub/
   export CONF_DIR=/etc/jupyterhub/

   # load the server config variables.
   source $CONF_DIR/jupyterhub.conf

   jupyterhub -f $CONF_DIR/config/$jupyter_config_file
   ```

   ```bash
   sudo chmod +x /opt/jupyterhub/run_jupyterhub.sh
   ```

   ```bash
   sudo vi /opt/jupyterhub/jupyterhub.service
   ```

   **Service Unit:**
   ```ini
   [Unit]
   Description=Jupyterhub Server
   After=network.target

   [Install]
   Alias=jupyterhub.service
   WantedBy=multi-user.target

   [Service]
   User=jupyterhub
   Group=fl_system
   Type=simple
   WorkingDirectory=/opt/jupyterhub/
   ExecStart=bash run_jupyterhub.sh
   Restart=always
   RestartSec=5
   ```

6. Enable and start JupyterHub
   ```bash
   sudo cp /opt/jupyterhub/jupyterhub.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable jupyterhub.service
   sudo systemctl start jupyterhub.service
   ```

**Configuration Files:**
- `/etc/jupyterhub/config/jupyterhub_config.py`
- `/etc/jupyterhub/jupyterhub.conf`
- `/opt/jupyterhub/run_jupyterhub.sh`
- `/etc/systemd/system/jupyterhub.service`

**Validation:**
```bash
# Check service status
sudo systemctl status jupyterhub.service

# Check logs
sudo journalctl -u jupyterhub.service -f

# Test web interface
curl -k https://jupyterhub.internal:8000/

# Test OAuth flow
# Access https://flhub.yourdomain.org.au in browser
# Should redirect to Keycloak login
```

---

## Phase 4: Federated Learning Components

### TASK-400: SuperLink Server Configuration
**Dependencies:** TASK-305, TASK-202, TASK-203
**Priority:** Critical
**Estimated Time:** 2 hours

**Implementation Steps:**
1. Copy certificates to SuperLink directory
   ```bash
   sudo cp /etc/ssl/certs/ca-certificates.crt /etc/flwr/superlink/certs/ca.crt
   sudo cp /etc/ssl/certs/superlink.pem /etc/flwr/superlink/certs/server.pem
   sudo cp /etc/ssl/private/superlink.key /etc/flwr/superlink/certs/server.key

   # Copy client public keys CSV (from TASK-203)
   sudo cp /tmp/client_public_keys.csv /etc/flwr/superlink/certs/

   sudo chown -R superlink:fl_system /etc/flwr/superlink/certs/
   sudo chmod 640 /etc/flwr/superlink/certs/*
   ```

2. Create SuperLink configuration
   ```bash
   sudo vi /etc/flwr/superlink/superlink.conf
   ```

   **Configuration:**
   ```bash
   # the superlink configuration file.

   # the server certificate key
   server_certificate_key=server.key
   server_certificate_pub=server.pem

   # the CA certificate key
   ca_certificate=ca.crt

   # allowed clients public keys csv.
   client_allowed_csv=client_public_keys.csv
   ```

3. Create SuperLink runtime directory
   ```bash
   sudo mkdir -p /opt/flwr/superlink
   sudo chown superlink:fl_system /opt/flwr/superlink
   ```

4. Create run script
   ```bash
   sudo vi /opt/flwr/superlink/run_superlink.sh
   ```

   **Script:**
   ```bash
   #!/bin/bash
   export PYTHONENV=/opt/python/flower_env/
   source $PYTHONENV/bin/activate

   cd /opt/flwr/superlink
   export TF_FORCE_GPU_ALLOW_GROWTH=true
   export PYTHONPATH=/opt/flwr/superlink/
   export CONF_DIR=/etc/flwr/superlink/

   # load the server config variables.
   source $CONF_DIR/superlink.conf

   # make sure the state directory is created
   mkdir -p $PYTHONPATH/temp

   flower-superlink \
     --ssl-ca-certfile $CONF_DIR/certs/$ca_certificate \
     --ssl-certfile $CONF_DIR/certs/$server_certificate_pub \
     --ssl-keyfile $CONF_DIR/certs/$server_certificate_key \
     --auth-list-public-keys $CONF_DIR/certs/$client_allowed_csv \
     --database $PYTHONPATH/temp/superlink_state.db
   ```

   ```bash
   sudo chmod +x /opt/flwr/superlink/run_superlink.sh
   sudo chown superlink:fl_system /opt/flwr/superlink/run_superlink.sh
   ```

5. Create systemd service
   ```bash
   sudo vi /opt/flwr/superlink/superlink.service
   ```

   **Service Unit:**
   ```ini
   [Unit]
   Description=Superlink Server
   After=network.target

   [Install]
   Alias=superlink.service
   WantedBy=multi-user.target

   [Service]
   User=superlink
   Group=fl_system
   Type=simple
   WorkingDirectory=/opt/flwr/superlink/
   ExecStart=bash run_superlink.sh
   Restart=always
   RestartSec=5
   ```

6. Enable and start SuperLink
   ```bash
   sudo cp /opt/flwr/superlink/superlink.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable superlink.service
   sudo systemctl start superlink.service
   ```

**Configuration Files:**
- `/etc/flwr/superlink/superlink.conf`
- `/etc/flwr/superlink/certs/ca.crt`
- `/etc/flwr/superlink/certs/server.pem`
- `/etc/flwr/superlink/certs/server.key`
- `/etc/flwr/superlink/certs/client_public_keys.csv`
- `/opt/flwr/superlink/run_superlink.sh`
- `/etc/systemd/system/superlink.service`

**Network Ports:**
- 9091: Flwr ServerAppIO API
- 9092: Flwr Fleet API
- 9093: Flwr Deployment Engine

**Validation:**
```bash
# Check service status
sudo systemctl status superlink.service

# Check logs
sudo journalctl -u superlink.service -f

# Verify ports listening
sudo netstat -tlnp | grep -E "9091|9092|9093"

# Check database created
ls -la /opt/flwr/superlink/temp/superlink_state.db
```

---

## Phase 5: Monitoring and Alerting

### TASK-500: Prometheus and Node Exporter Installation
**Dependencies:** TASK-104
**Priority:** High
**Estimated Time:** 2 hours

**Implementation Steps:**
1. Install Prometheus on monitoring server
   ```bash
   sudo apt install -y prometheus
   ```

2. Install Prometheus Node Exporter on all servers
   ```bash
   # On each server to be monitored
   sudo apt install -y prometheus-node-exporter
   ```

3. Configure Node Exporter custom port (optional)
   ```bash
   sudo vi /etc/default/prometheus-node-exporter
   ```

   **Configuration:**
   ```bash
   ARGS="--web.listen-address=:9900"
   ```

4. Enable and start Node Exporter
   ```bash
   sudo systemctl enable prometheus-node-exporter
   sudo systemctl restart prometheus-node-exporter
   ```

5. Configure Prometheus scrape targets
   ```bash
   sudo vi /etc/prometheus/prometheus.yml
   ```

   **Configuration:**
   ```yaml
   global:
     scrape_interval: 30s
     evaluation_interval: 30s

   scrape_configs:
     - job_name: 'prometheus'
       scrape_interval: 30s
       scrape_timeout: 5s
       static_configs:
         - targets: ['localhost:9090']

     - job_name: 'node'
       scrape_interval: 30s
       scrape_timeout: 5s
       static_configs:
         - targets:
           - 'vpnserver.internal:9900'
           - 'nginx.internal:9900'
           - 'keycloak.internal:9900'
           - 'jupyterhub.internal:9900'
           - 'superlink.internal:9900'
           # Add client SuperNodes via VPN
           - 'supernode1.vpn:9900'
           - 'supernode2.vpn:9900'
   ```

6. Configure Prometheus storage retention
   ```bash
   sudo vi /etc/default/prometheus
   ```

   **Configuration:**
   ```bash
   ARGS="--storage.tsdb.retention.time=7d --storage.tsdb.retention.size=512MB"
   ```

7. Enable and restart Prometheus
   ```bash
   sudo systemctl enable prometheus
   sudo systemctl restart prometheus
   ```

**Configuration Files:**
- `/etc/prometheus/prometheus.yml`
- `/etc/default/prometheus`
- `/etc/default/prometheus-node-exporter`

**Validation:**
```bash
# Verify Node Exporter on each server
curl http://localhost:9900/metrics | head -20

# Verify Prometheus
curl http://localhost:9090/api/v1/targets | jq

# Check service status
sudo systemctl status prometheus
sudo systemctl status prometheus-node-exporter

# Test connectivity to remote exporters
curl http://supernode1.vpn:9900/metrics | head -10
```

---

### TASK-501: GPU Monitoring Setup (NVIDIA DCGM)
**Dependencies:** TASK-500
**Priority:** Medium
**Estimated Time:** 3 hours per GPU server

**Applicable Servers:**
- SuperLink (if GPU-enabled)
- SuperNode clients (with GPUs)

**Implementation Steps:**
1. Install NVIDIA DCGM
   ```bash
   # Add NVIDIA repository (same as CUDA repo)
   sudo apt install -y datacenter-gpu-manager
   ```

2. Enable and start DCGM service
   ```bash
   sudo systemctl enable nvidia-dcgm
   sudo systemctl start nvidia-dcgm
   sudo systemctl status nvidia-dcgm
   ```

3. Build DCGM Exporter
   ```bash
   # Install build dependencies
   sudo apt install -y gcc golang-go

   # Clone and build
   mkdir -p ~/nvidia-dcgm
   cd ~/nvidia-dcgm
   git clone https://github.com/NVIDIA/dcgm-exporter.git
   cd dcgm-exporter

   # Get version compatible with DCGM 3.3.9
   git fetch origin 3.3.9-3.6.1
   git checkout 3.3.9-3.6.1

   make binary
   sudo make install
   ```

4. Test DCGM Exporter
   ```bash
   sudo dcgm-exporter --address=":9400"
   # Ctrl+C to exit after testing
   ```

5. Create systemd service
   ```bash
   sudo vi /usr/lib/systemd/system/dcgm-exporter.service
   ```

   **Service Unit:**
   ```ini
   [Unit]
   Description=DCGM Exporter
   After=network.target
   After=nvidia-dcgm.service
   Wants=nvidia-dcgm.service

   [Install]
   Alias=dcgm-exporter.service
   WantedBy=multi-user.target

   [Service]
   User=root
   PrivateTmp=false
   Type=simple
   ExecStart=dcgm-exporter --address=":9400"
   Restart=always
   RestartSec=5
   ```

6. Enable and start DCGM Exporter
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable dcgm-exporter.service
   sudo systemctl start dcgm-exporter.service
   ```

7. Add GPU nodes to Prometheus config
   ```bash
   # On monitoring server
   sudo vi /etc/prometheus/prometheus.yml
   ```

   **Add job:**
   ```yaml
     - job_name: 'gpu_nodes'
       scrape_interval: 30s
       scrape_timeout: 5s
       static_configs:
         - targets:
           - 'superlink.internal:9400'
           - 'supernode1.vpn:9400'
           - 'supernode2.vpn:9400'
   ```

8. Restart Prometheus
   ```bash
   sudo systemctl restart prometheus
   ```

**Configuration Files:**
- `/usr/lib/systemd/system/dcgm-exporter.service`
- `/etc/prometheus/prometheus.yml` (updated)

**Validation:**
```bash
# Verify DCGM service
sudo systemctl status nvidia-dcgm

# Verify DCGM Exporter
sudo systemctl status dcgm-exporter
curl http://localhost:9400/metrics | grep DCGM

# Test GPU metrics
curl http://localhost:9400/metrics | grep DCGM_FI_DEV_GPU_TEMP

# Check Prometheus targets
curl http://<monitoring-server>:9090/api/v1/targets | jq '.data.activeTargets[] | select(.job == "gpu_nodes")'
```

---

### TASK-502: Grafana Installation and Configuration
**Dependencies:** TASK-500, TASK-300
**Priority:** High
**Estimated Time:** 3 hours

**Implementation Steps:**
1. Install Grafana
   ```bash
   # On monitoring server
   sudo apt install -y apt-transport-https software-properties-common wget

   wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
   echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

   sudo apt update
   sudo apt install -y grafana
   ```

2. Create Grafana database (on PostgreSQL server)
   ```bash
   sudo -u postgres psql -h <postgres-host> -p 5432
   ```

   ```sql
   CREATE ROLE grafana WITH
     LOGIN
     NOSUPERUSER
     INHERIT
     CREATEDB
     CREATEROLE
     PASSWORD 'STRONG_PASSWORD_HERE';

   CREATE DATABASE grafanadb_server
     WITH
     OWNER = grafana
     ENCODING = 'UTF8'
     LC_COLLATE = 'en_AU.UTF-8'
     LC_CTYPE = 'en_AU.UTF-8'
     LOCALE_PROVIDER = 'libc'
     TABLESPACE = pg_default
     CONNECTION LIMIT = -1
     IS_TEMPLATE = False;

   \c grafanadb_server
   CREATE SCHEMA IF NOT EXISTS grafana AUTHORIZATION grafana;
   ```

3. Configure Grafana
   ```bash
   sudo vi /etc/grafana/grafana.ini
   ```

   **Key Configurations:**
   ```ini
   [database]
   type = postgres
   host = <postgres-host>:5432
   name = grafanadb_server
   user = grafana
   password = STRONG_PASSWORD_HERE
   url = postgres://grafana:STRONG_PASSWORD_HERE@<postgres-host>:5432/grafanadb_server?options=-csearch_path=grafana

   [server]
   protocol = https
   http_port = 3000
   domain = monitoring.yourdomain.org.au
   root_url = https://monitoring.yourdomain.org.au/
   cert_file = /etc/ssl/certs/grafana.pem
   cert_key = /etc/ssl/private/grafana.key

   [auth.generic_oauth]
   enabled = true
   name = Keycloak
   allow_sign_up = true
   client_id = flower_auth_client
   client_secret = <keycloak-client-secret>
   scopes = openid email profile
   auth_url = https://keycloak.yourdomain.org.au/realms/flowerfl/protocol/openid-connect/auth
   token_url = https://keycloak.internal:8443/realms/flowerfl/protocol/openid-connect/token
   api_url = https://keycloak.internal:8443/realms/flowerfl/protocol/openid-connect/userinfo
   role_attribute_path = contains(groups[*], 'grafana_admins') && 'Admin' || 'Viewer'

   [smtp]
   enabled = true
   host = <smtp-server>:587
   user = <smtp-user>
   password = <smtp-password>
   from_address = monitoring@yourdomain.org.au
   from_name = Grafana Monitoring
   ```

4. Enable and start Grafana
   ```bash
   sudo systemctl enable grafana-server
   sudo systemctl start grafana-server
   ```

5. Configure Prometheus data source in Grafana
   - Navigate to: Configuration > Data Sources > Add data source
   - Select: Prometheus
   - URL: `http://localhost:9090`
   - Save & Test

**Configuration Files:**
- `/etc/grafana/grafana.ini`

**Validation:**
```bash
# Check service status
sudo systemctl status grafana-server

# Check logs
sudo tail -f /var/log/grafana/grafana.log

# Test web interface
curl -k https://localhost:3000/

# Test data source
curl -u admin:admin http://localhost:3000/api/datasources
```

---

### TASK-503: Grafana Alerting Configuration
**Dependencies:** TASK-502
**Priority:** High
**Estimated Time:** 4 hours

**Alert Rules to Create:**

1. **CPU Load Alert**
   - Query: `node_load15/(count without(cpu, mode) (node_cpu_seconds_total{mode="idle"}))`
   - Threshold: > 0.8 for 30 minutes (Medium), > 0.95 for 30 minutes (High)

2. **Memory Usage Alert**
   - Query: `node_memory_MemFree_bytes / node_memory_MemAvailable_bytes`
   - Threshold: < 0.1 for 30 minutes (Medium), < 0.05 for 30 minutes (High)

3. **Disk Space Alert**
   - Query: `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}`
   - Threshold: < 0.3 (Low), < 0.2 (Medium), < 0.1 (High)

4. **Service Failed Alert**
   - Query: `node_systemd_unit_state{name="<service>.service", state=~"failed|inactive"}`
   - Threshold: > 0 for 5 minutes

5. **GPU Temperature Alert**
   - Query: `DCGM_FI_DEV_GPU_TEMP{gpu=~"(0|1)"}`
   - Threshold: >= 85°C for 30 minutes

6. **GPU Memory Alert**
   - Query: `DCGM_FI_DEV_MEM_COPY_UTIL{gpu=~"(0|1)"}`
   - Threshold: > 90% for 1 hour

**Implementation Steps:**
1. Access Grafana UI
   - Navigate to: Alerting > Alert rules > New alert rule

2. Create each alert rule with:
   - Name: Descriptive alert name
   - Query: As specified above
   - Condition: Threshold expression
   - Evaluation: Interval and for duration
   - Labels: severity (low/medium/high), service, host

3. Create notification policies
   - Navigate to: Alerting > Notification policies
   - Create policies based on severity labels
   - Route to appropriate contact points

4. Create contact points
   - Navigate to: Alerting > Contact points
   - Email: Operations team email
   - Slack: Optional Slack webhook (if configured)

**Alert Rule Examples:**

**CPU Load Alert Rule:**
```yaml
Alert Name: High CPU Load
Query A: node_load15/(count without(cpu, mode) (node_cpu_seconds_total{mode="idle"}))
Condition: WHEN avg() OF A IS ABOVE 0.8
For: 30m
Labels:
  severity: medium
  component: system
Annotations:
  summary: High CPU load on {{ $labels.instance }}
  description: CPU load is {{ $value }} on {{ $labels.instance }}
```

**Service Down Alert Rule:**
```yaml
Alert Name: Service Failed - SuperLink
Query A: node_systemd_unit_state{name="superlink.service", state=~"failed|inactive"}
Condition: WHEN last() OF A IS ABOVE 0
For: 5m
Labels:
  severity: high
  service: superlink
  component: federated-learning
Annotations:
  summary: SuperLink service is down on {{ $labels.instance }}
  description: SuperLink service has failed or is inactive
```

**Validation:**
```bash
# Test alert rules from Prometheus
curl 'http://localhost:9090/api/v1/rules' | jq '.data.groups[].rules[] | select(.type == "alerting")'

# Check Grafana alerts
curl -u admin:admin 'http://localhost:3000/api/v1/provisioning/alert-rules' | jq

# Test email notifications (trigger test alert)
# In Grafana UI: Alerting > Contact points > Test
```

**Documentation:**
- Document all alert rules and thresholds
- Create runbook for each alert (what to do when alert fires)
- Document escalation procedures

---

## Phase 6: Client Deployment

### TASK-600: VPN Client Installation (Organization Side)
**Dependencies:** TASK-205
**Priority:** Critical
**Estimated Time:** 2 hours per client

**Applicable To:** Each participating organization's SuperNode server

**Implementation Steps:**
1. Receive VPN client configuration package
   - Securely obtain `client-vpn-config.tar.gz` from QCIF

2. Extract configuration
   ```bash
   cd /tmp
   tar -xzf client-vpn-config.tar.gz
   sudo mkdir -p /etc/openvpn/clientcerts
   sudo cp -r client/. /etc/openvpn/clientcerts/
   sudo chmod 600 /etc/openvpn/clientcerts/*.key
   sudo chmod 600 /etc/openvpn/clientcerts/ta.key
   ```

3. Install OpenVPN client
   ```bash
   sudo apt install -y openvpn
   ```

4. Create client configuration
   ```bash
   sudo vi /etc/openvpn/client/client.conf
   ```

   **Configuration:**
   ```
   client
   proto udp
   remote <vpn-server-public-ip> 1194
   dev tap
   nobind

   remote-cert-tls server

   ca /etc/openvpn/clientcerts/ca.crt
   cert /etc/openvpn/clientcerts/client1.crt
   key /etc/openvpn/clientcerts/client1.key
   tls-auth /etc/openvpn/clientcerts/ta.key 1

   persist-key
   persist-tun
   keepalive 10 60

   verb 3
   log-append /var/log/openvpn/client.log
   ```

5. Test VPN connection
   ```bash
   sudo openvpn --config /etc/openvpn/client/client.conf
   # Verify connection, then Ctrl+C
   ```

6. Enable VPN client service
   ```bash
   sudo systemctl enable openvpn-client@client.service
   sudo systemctl start openvpn-client@client.service
   ```

7. Verify connectivity to internal network
   ```bash
   # Should be able to reach internal network
   ping -c 4 superlink.internal
   ping -c 4 10.255.x.x
   ```

**Configuration Files:**
- `/etc/openvpn/client/client.conf`
- `/etc/openvpn/clientcerts/ca.crt`
- `/etc/openvpn/clientcerts/client1.crt`
- `/etc/openvpn/clientcerts/client1.key`
- `/etc/openvpn/clientcerts/ta.key`

**Validation:**
```bash
# Check VPN service status
sudo systemctl status openvpn-client@client.service

# Verify VPN interface
ip addr show tap0

# Test connectivity to SuperLink
telnet superlink.internal 9092

# Test DNS resolution
nslookup superlink.internal

# Check logs
sudo tail -f /var/log/openvpn/client.log
```

---

### TASK-601: SuperNode Installation (Organization Side)
**Dependencies:** TASK-600, TASK-103, TASK-104, TASK-305
**Priority:** Critical
**Estimated Time:** 3 hours per SuperNode

**Implementation Steps:**
1. Receive SuperNode certificates from QCIF
   - Public/private key pair: `client_credentials_N`, `client_credentials_N.pub`
   - CA certificate: `ca.crt`

2. Install certificates
   ```bash
   sudo mkdir -p /etc/flwr/supernode/certs
   sudo cp /tmp/client_credentials_1 /etc/flwr/supernode/certs/
   sudo cp /tmp/client_credentials_1.pub /etc/flwr/supernode/certs/
   sudo cp /tmp/ca.crt /etc/flwr/supernode/certs/

   sudo chown -R supernode:fl_system /etc/flwr/supernode/certs/
   sudo chmod 600 /etc/flwr/supernode/certs/client_credentials_1
   sudo chmod 644 /etc/flwr/supernode/certs/client_credentials_1.pub
   sudo chmod 644 /etc/flwr/supernode/certs/ca.crt
   ```

3. Create SuperNode configuration
   ```bash
   sudo vi /etc/flwr/supernode/supernode.conf
   ```

   **Configuration:**
   ```bash
   # supernode configuration file

   # the superlink server address to connect to
   superlink_server=superlink.internal
   superlink_port=9092

   # the local ip address defaults to 0.0.0.0
   local_address=0.0.0.0

   # the local port for the clientapi io of the flower supernode
   local_port=9094

   # the partition this system represents (must be unique in cluster)
   local_partition=0

   # The total number of partitions in the cluster
   num_partitions=4

   # the client credentials certificates
   client_credentials_key=client_credentials_1
   client_credentials_pub=client_credentials_1.pub
   ca_certificate=ca.crt
   ```

4. Create SuperNode runtime directory
   ```bash
   sudo mkdir -p /opt/flwr/supernode
   sudo chown supernode:fl_system /opt/flwr/supernode
   ```

5. Create run script
   ```bash
   sudo vi /opt/flwr/supernode/run_supernode.sh
   ```

   **Script:**
   ```bash
   #!/bin/bash
   export PYTHONENV=/opt/python/flower_env/
   source $PYTHONENV/bin/activate

   cd /opt/flwr/supernode
   export TF_FORCE_GPU_ALLOW_GROWTH=true
   export PYTHONPATH=/opt/flwr/supernode/
   export CONF_DIR=/etc/flwr/supernode/

   # load the configuration variables
   source $CONF_DIR/supernode.conf

   echo "Connect to superlink $superlink_server Port: $superlink_port"
   echo "Local address: $local_address Local port: $local_port"
   echo "Partition Id: $local_partition Num-partitions: $num_partitions"

   flower-supernode \
     --root-certificates $CONF_DIR/certs/$ca_certificate \
     --superlink $superlink_server:$superlink_port \
     --clientappio-api-address $local_address:$local_port \
     --node-config="partition-id=$local_partition num-partitions=$num_partitions" \
     --auth-supernode-private-key $CONF_DIR/certs/$client_credentials_key \
     --auth-supernode-public-key $CONF_DIR/certs/$client_credentials_pub
   ```

   ```bash
   sudo chmod +x /opt/flwr/supernode/run_supernode.sh
   sudo ch