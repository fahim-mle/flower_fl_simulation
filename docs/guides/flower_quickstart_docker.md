# Quickstart with Docker

Containerize a Flower federated learning project and run it end-to-end with this guide, including SuperLink, SuperNode, ServerApp, and ClientApp setup.

> **Note**
> This tutorial does not use production-ready settings, so you can focus on understanding the basic workflow using the minimum configurations.

---

## Prerequisites

Before you start, make sure that:

- The `flwr` CLI is [installed](../how-to-install-flower) locally.
- The Docker daemon is running.

---

## Step 1: Set Up

### 1. Create a new Flower project (PyTorch):

```bash
flwr new quickstart-docker --framework PyTorch --username flower

cd quickstart-docker && pip install -e .
flwr run .
cd quickstart-docker
```

### 2. Create a new Docker bridge network called `flwr-network`:

```bash
docker network create --driver bridge flwr-network
```

> User-defined networks, such as `flwr-network`, enable IP resolution of container names, a feature absent in the default bridge network. This simplifies the quickstart example by avoiding the need to determine the host IP first.

---

## Step 2: Start the SuperLink

Run the SuperLink container:

```bash
docker run --rm   -p 9091:9091 -p 9092:9092 -p 9093:9093   --network flwr-network   --name superlink   --detach   flwr/superlink:|stable_flwr_version|   --insecure   --isolation process
```

**Explanation:**

- `--rm`: Remove the container once it stops.
- `-p`: Map ports `9091`, `9092`, `9093` for ServerAppIO API, Fleet API, and Control API.
- `--network`: Join the `flwr-network`.
- `--detach`: Run in background.
- `--insecure`: Allow unencrypted communication.
- `--isolation process`: Run ServerApp as a separate process.

---

## Step 3: Start the SuperNodes

Start **two SuperNode containers**.

### 1. First SuperNode:

```bash
docker run --rm   -p 9094:9094   --network flwr-network   --name supernode-1   --detach   flwr/supernode:|stable_flwr_version|    --insecure   --superlink superlink:9092   --node-config "partition-id=0 num-partitions=2"   --clientappio-api-address 0.0.0.0:9094   --isolation process
```

### 2. Second SuperNode:

```bash
docker run --rm   -p 9095:9095   --network flwr-network   --name supernode-2   --detach   flwr/supernode:|stable_flwr_version|    --insecure   --superlink superlink:9092   --node-config "partition-id=1 num-partitions=2"   --clientappio-api-address 0.0.0.0:9095   --isolation process
```

---

## Step 4: Start the SuperExec to Execute ServerApps

### 1. Create a `superexec.Dockerfile`:

```dockerfile
# superexec.Dockerfile
FROM flwr/superexec:|stable_flwr_version|

WORKDIR /app

COPY pyproject.toml .
RUN sed -i 's/.*flwr\[simulation\].*//' pyproject.toml     && python -m pip install -U --no-cache-dir .

ENTRYPOINT ["flower-superexec"]
```

### 2. Build the SuperExec image:

```bash
docker build -f superexec.Dockerfile -t flwr_superexec:0.0.1 .
```

### 3. Start the SuperExec container for ServerApps:

```bash
docker run --rm   --network flwr-network   --name superexec-serverapp   --detach   flwr_superexec:0.0.1   --insecure   --plugin-type serverapp   --appio-api-address superlink:9091
```

---

## Step 5: Start the SuperExec to Execute ClientApps

Reuse the **same image**, but change the plugin type and API address.

### 1. First ClientApp:

```bash
docker run --rm   --network flwr-network   --name superexec-clientapp-1   --detach   flwr_superexec:0.0.1   --insecure   --plugin-type clientapp   --appio-api-address supernode-1:9094
```

### 2. Second ClientApp:

```bash
docker run --rm   --network flwr-network   --name superexec-clientapp-2   --detach   flwr_superexec:0.0.1   --insecure   --plugin-type clientapp   --appio-api-address supernode-2:9095
```

---

## Step 6: Run the Quickstart Project

### 1. Update `pyproject.toml`:

```toml
[tool.flwr.federations.local-deployment]
address = "127.0.0.1:9093"
insecure = true
```

### 2. Run the project:

```bash
flwr run . local-deployment --stream
```

---

## Step 7: Update the Application

### 1. Modify the app (e.g., `quickstart_docker/task.py`):

```python
# quickstart_docker/task.py
partition_train_test = partition.train_test_split(test_size=0.2, seed=43)
```

### 2. Stop running containers:

> If you changed dependencies in `pyproject.toml`, rebuild the image. Otherwise, skip steps 2–4.

```bash
docker stop $(docker ps -a -q --filter ancestor=flwr_superexec:0.0.1)
```

### 3. Rebuild the image:

```bash
docker build -f superexec.Dockerfile -t flwr_superexec:0.0.1 .
```

### 4. Relaunch containers:

```bash
# ServerApp
docker run --rm   --network flwr-network   --name superexec-serverapp   --detach   flwr_superexec:0.0.1   --insecure   --plugin-type serverapp   --appio-api-address superlink:9091

# First ClientApp
docker run --rm   --network flwr-network   --name superexec-clientapp-1   --detach   flwr_superexec:0.0.1   --insecure   --plugin-type clientapp   --appio-api-address supernode-1:9094

# Second ClientApp
docker run --rm   --network flwr-network   --name superexec-clientapp-2   --detach   flwr_superexec:0.0.1   --insecure   --plugin-type clientapp   --appio-api-address supernode-2:9095
```

### 5. Run the updated project:

```bash
flwr run . local-deployment --stream
```

---

## Step 8: Clean Up

Stop and remove containers, then remove the Docker network:

```bash
docker stop $(docker ps -a -q --filter ancestor=flwr_superexec:0.0.1)   supernode-1   supernode-2   superlink

docker network rm flwr-network
```

---

## Where to Go Next

- [Enable TLS](enable-tls)
- [Persist SuperLink state](persist-superlink-state)
- [Quickstart with Docker Compose](tutorial-quickstart-docker-compose)


# Quickstart with Docker

This quickstart aims to guide you through the process of containerizing a Flower project and running it end to end using Docker on your local machine.

This tutorial does not use production-ready settings, so you can focus on understanding the basic workflow that uses the minimum configurations.

**Prerequisites**

Before you start, make sure that:

The flwr CLI is installed locally.

The Docker daemon is running.

## Step 1: Set Up
Create a new Flower project (PyTorch):

```bash
flwr new quickstart-docker --framework PyTorch --username flower

🔨 Creating Flower App quickstart-docker...
🎊 Flower App creation successful.

To run your Flower App, first install its dependencies:

        cd quickstart-docker && pip install -e .

then, run the app:

        flwr run .

💡 Check the README in your app directory to learn how to
customize it and how to run it using the Deployment Runtime.

cd quickstart-docker
```
Create a new Docker bridge network called flwr-network:

```bash
docker network create --driver bridge flwr-network

```

User-defined networks, such as flwr-network, enable IP resolution of container names, a feature absent in the default bridge network. This simplifies quickstart example by avoiding the need to determine host IP first.

## Step 2: Start the SuperLink
Open your terminal and run:

```bash
docker run --rm \
      -p 9091:9091 -p 9092:9092 -p 9093:9093 \
      --network flwr-network \
      --name superlink \
      --detach \
      flwr/superlink:1.22.0 \
      --insecure \
      --isolation \
      process
```
# Understand the command

`docker run`: This tells Docker to run a container from an image.

`--rm`: Remove the container once it is stopped or the command exits.

`-p 9091:9091 -p 9092:9092 -p 9093:9093`: Map port 9091, 9092 and 9093 of the container to the same port of the host machine, allowing other services to access the ServerAppIO API on http://localhost:9091, the Fleet API on http://localhost:9092 and the Control API on http://localhost:9093.

`--network flwr-network`: Make the container join the network named flwr-network.

`--name superlink`: Assign the name superlink to the container.

`--detach`: Run the container in the background, freeing up the terminal.

`flwr/superlink:1.22.0`: The name of the image to be run and the specific tag of the image. The tag 1.22.0 represents a specific version of the image.

`--insecure`: This flag tells the container to operate in an insecure mode, allowing unencrypted communication.

`--isolation process`: Tells the SuperLink that the ServerApp is executed by separate independent process. The SuperLink does not attempt to execute it. You can learn more about the different process modes here: Run ServerApp or ClientApp as a Subprocess.

## Step 3: Start the SuperNodes
Start two SuperNode containers.

Start the first container:

```bash
docker run --rm \
    -p 9094:9094 \
    --network flwr-network \
    --name supernode-1 \
    --detach \
    flwr/supernode:1.22.0  \
    --insecure \
    --superlink superlink:9092 \
    --node-config "partition-id=0 num-partitions=2" \
    --clientappio-api-address 0.0.0.0:9094 \
    --isolation process
Start the second container:

docker run --rm \
    -p 9095:9095 \
    --network flwr-network \
    --name supernode-2 \
    --detach \
    flwr/supernode:1.22.0  \
    --insecure \
    --superlink superlink:9092 \
    --node-config "partition-id=1 num-partitions=2" \
    --clientappio-api-address 0.0.0.0:9095 \
    --isolation process
```

## Step 4: Start the SuperExec to execute ServerApps

The `SuperExec` Docker image comes with a pre-installed version of Flower and serves as a base for building your own image. Use a **single** image and select the desired behavior (ServerApps vs ClientApps) at runtime via the `--plugin-type` flag. SuperExec spawns the corresponding processes on demand.

When using SuperExec with the serverapp plugin, pass `--appio-api-address` pointing to the SuperLink’s ServerAppIO API endpoint.

1. Create a Dockerfile called superexec.Dockerfile and paste the following:

superexec.Dockerfile

```dockerfile
FROM flwr/superexec:1.22.0

WORKDIR /app

COPY pyproject.toml .
RUN sed -i 's/.*flwr\[simulation\].*//' pyproject.toml \
   && python -m pip install -U --no-cache-dir .

ENTRYPOINT ["flower-superexec"]
```

### Understand the Dockerfile

*  `FROM flwr/superexec:1.22.0`: This line specifies that the Docker image to be built from is the `flwr/superexec` image, version `1.22.0`.

*  `WORKDIR /app`: Set the working directory for the container to `/app`. Any subsequent commands that reference a directory will be relative to this directory.

* `COPY pyproject.toml .`: Copy the `pyproject.toml` file. from the current working directory into the container’s `/app` directory.

* `RUN sed -i 's/.*flwr\[simulation\].*//' pyproject.toml`: Remove the flwr dependency from the `pyproject.toml`.

* `python -m pip install -U --no-cache-dir .`: Run the `pip install` command to install the dependencies defined in the `pyproject.toml` file.

* The `-U` flag indicates that any existing packages should be upgraded, and `--no-cache-dir` prevents pip from using the cache to speed up the installation.

* `ENTRYPOINT ["flower-superexec"]`: Set the command `flower-superexec` to be the default command run when the container is started.

#### Important

Note that `flwr` is already installed in the `flwr/superexec` base image, so only other package dependencies such as `flwr-datasets`, `torch`, etc., need to be installed. As a result, the `flwr` dependency is removed from the pyproject.toml after it has been copied into the Docker image (see line 5).

2. Afterward, in the directory that holds the Dockerfile, execute this Docker command to build the SuperExec image:

```bash
docker build -f superexec.Dockerfile -t flwr_superexec:0.0.1 .
```

3. Start the SuperExec for ServerApps container:

```bash
docker run --rm \
    --network flwr-network \
    --name superexec-serverapp \
    --detach \
    flwr_superexec:0.0.1 \
    --insecure \
    --plugin-type serverapp \
    --appio-api-address superlink:9091
```

## Step 5: Start the SuperExec to execute ClientApps

For ClientApps, reuse the **same** image and change the plugin and API address. When using the clientapp plugin, pass `--appio-api-address` pointing to the SuperNode’s **ClientAppIO API** endpoint.

1. (No new Dockerfile is needed; reuse flwr_superexec:0.0.1.)

2. Start the first SuperExec for ClientApps container:

```bash
docker run --rm \
    --network flwr-network \
    --name superexec-clientapp-1 \
    --detach \
    flwr_superexec:0.0.1 \
    --insecure \
    --plugin-type clientapp \
    --appio-api-address supernode-1:9094
```

* `docker run`: This tells Docker to run a container from an image.

* `--rm`: Remove the container once it is stopped or the command exits.

* `--network flwr-network`: Make the container join the network named `flwr-network`.

* `--name superexec-clientapp-1`: Give the container a descriptive name.

* `--detach`: Run the container in the background, freeing up the terminal.

* `flwr_superexec:0.0.1`: This is the name of the image to be run and the specific tag of the image.

* `--insecure`: This flag tells the container to operate in an insecure mode, allowing unencrypted communication. Secure connections will be added in future releases.

* `--plugin-type clientapp`: Load the clientapp plugin. SuperExec will spawn ClientApp processes as needed.

* `--appio-api-address supernode-1:9094`: Connect to the SuperNode’s ClientAppIO API at the address supernode-1:9094.

3. Start the second SuperExec for ClientApps container:

```bash
docker run --rm \
    --network flwr-network \
    --name superexec-clientapp-2 \
    --detach \
    flwr_superexec:0.0.1 \
    --insecure \
    --plugin-type clientapp \
    --appio-api-address supernode-2:9095
```

## Step 6: Run the Quickstart Project

Add the following lines to the pyproject.toml:

pyproject.toml

```toml
[tool.flwr.federations.local-deployment]
address = "127.0.0.1:9093"
insecure = true
```

Run the quickstart-docker project and follow the ServerApp logs to track the execution of the run:

```bash
flwr run . local-deployment --stream
```

## Step 7: Update the Application

1. Change the application code. For example, change the seed in quickstart_docker/task.py to 43 and save it:

quickstart_docker/task.py

```py
# ...
partition_train_test = partition.train_test_split(test_size=0.2, seed=43)
# ...
```

2. Stop the running containers:

*Note*

If you have modified the dependencies listed in your pyproject.toml file, it is essential to rebuild images.

If you haven’t made any changes, you can skip steps 2 through 4.

```bash
docker stop $(docker ps -a -q --filter ancestor=flwr_superexec:0.0.1)
```

3. Rebuild the SuperExec image:

```bash
docker build -f superexec.Dockerfile -t flwr_superexec:0.0.1 .
```

4. Launch one SuperExec container for the new ServerApp and two SuperExec containers for the new ClientApps:

```bash
docker run --rm \
    --network flwr-network \
    --name superexec-serverapp \
    --detach \
    flwr_superexec:0.0.1 \
    --insecure \
    --plugin-type serverapp \
    --appio-api-address superlink:9091
docker run --rm \
    --network flwr-network \
     --name superexec-clientapp-1 \
    --detach \
    flwr_superexec:0.0.1 \
    --insecure \
    --plugin-type clientapp \
    --appio-api-address supernode-1:9094
docker run --rm \
    --network flwr-network \
    --name superexec-clientapp-2 \
    --detach \
    flwr_superexec:0.0.1 \
    --insecure \
    --plugin-type clientapp \
    --appio-api-address supernode-2:9095
```

5. Run the updated project:

```bash
flwr run . local-deployment --stream
```

## Step 8: Clean Up

Remove the containers and the bridge network:

```bash
$ docker stop $(docker ps -a -q --filter ancestor=flwr_superexec:0.0.1) \
   supernode-1 \
   supernode-2 \
   superlink
docker network rm flwr-network
```
