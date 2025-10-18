# Federated Learning Brief

## Overview

Federated Learning (FL) enables secure access to medical data to train machine learning models by transmitting only model parameters instead of data. This allows external medical organizations to support trusted research partnerships by allowing ML models to be trained on data within a secure partition without direct researcher access to datasets.

## Core Components

### System Entities

- **Researcher**: Trusted user with access to the interface layer for modeling and analysis
- **Superlink**: Coordinator during training process, handles aggregation (hosted in Nectar)
- **Supernode**: On-premise execution node that provides access to local datasets
- **Datasets**: Secure data stored within organizational boundaries

### Architecture

- **Hybrid Cloud Deployment**: Superlink in Nectar cloud, Supernodes on client premises
- **Secure Communication**: VPN and mTLS certificates enable secure communication
- **No Data Transfer**: Only model parameters are transmitted, data remains on-premise

## Security Framework

- **Multi-layer security**: Network segmentation, certificate-based authentication, transport encryption
- **Mutual TLS**: Authentication between superlink and supernodes
- **Role-based Access**: Keycloak for OIDC authentication
- **Isolated Network Segments**: Firewalls filter traffic between components

## Deployment Components

### Server Environment

- Ubuntu 24.04 LTS recommended OS
- Python 3.12 virtual environment
- Flower Superlink with mTLS certificates
- GPU acceleration required for vertical FL
- Keycloak for authentication
- Nginx reverse proxy

### Client Environment

- Python 3.12 virtual environment
- Flower Supernode
- GPU acceleration for training
- mTLS certificates for authentication

## Key Benefits

- **Data Privacy**: Sensitive data never leaves organizational boundaries
- **Secure Collaboration**: Enables research partnerships without data exposure
- **Compliance**: Maintains control over sensitive datasets
- **Efficiency**: Only parameters transmitted, reducing bandwidth needs

## Critical Ports and Protocols

- **SSH**: Port 22 (public)
- **HTTPS**: Port 443 (public via Nginx)
- **FL Server**: Ports 9091-9093 (internal)
- **FL Clients**: Ports 9094-9099 (internal)
- **VPN**: Port 1194 UDP (public)

## Deployment Considerations

- Use systemd for service management
- Implement monitoring with Grafana/Prometheus
- Configure certificate authorities for mutual authentication
- Plan for GPU monitoring if using hardware acceleration
- Establish proper logging and alerting procedures
