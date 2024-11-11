
# Project Setup: Hashicorp Vault with Kubernetes and SSL/TLS Secured Service

This project integrates HashiCorp Vault with Kubernetes and secures a custom service (`myservice`) using SSL/TLS. The setup uses mTLS for secure communication between NGINX Ingress and `myservice`, ensuring client certificates are used for verification.

## Prerequisites
- Docker Desktop with Kubernetes enabled
- OpenSSL
- `kubectl` CLI installed and configured

---

## Steps to Spin Up the Project Locally

### 1. Bring Up the Project
Run the following command:
```bash
make up
```
This command will:
- Add `myservice.example.com` to `/etc/hosts`.
- Build `myservice` image from `./myservice/Dockerfile`
- Install NGINX Ingress Controller with helm.
- Deploy HashiCorp Vault with helm and configure it using sctipt in `./scripts/setup_vault.sh`.
- Generate SSL/TLS certificates with script `./scripts/makecerts.sh` and import them into Kubernetes etcd.
- Deploy `myservice` using k8s manifests from `./k8s/myservice/`.

### 2. Accessing `myservice`
Once the setup is complete, you can access `myservice` with a client certificate using:
```bash
curl --cacert ./certs/ca.crt \
     --cert ./certs/client.crt \
     --key ./certs/client.key \
     https://myservice.example.com/
```

### 3. Cleanup
Once you are done, run the following command to clean up the project:
```bash
make down
```

---

## Explanation of Files and Components

### 1. `Makefile`
The `Makefile` automates the setup process.

### 2. `makecerts.sh`
Automates the creation of SSL/TLS certificates.
- Generates CA, client, and server certificates for example.com with alt on wildcard *.example.com.
- Uses OpenSSL to ensure all keys and certificates are signed by the designated CA.
- The generated certificates are stored in the `certs` directory.


### 3. `setup_vault.sh`
Configures HashiCorp Vault and enables Kubernetes authentication.
- Waits for the Vault pod to be in a running state.
- Configures Vault to use Kubernetes authentication.
- Defines a Vault policy (`myservice`) for accessing secrets.
- Creates and writes secrets into Vault.

**Important Steps in `setup_vault.sh`**:
- **Vault Authentication**: Enables Kubernetes authentication for secure communication.
- **Policy Setup**: Grants `myservice` the ability to read secrets.
- **Secrets Management**: Stores and verifies the secrets in Vault.

---

## Kubernetes Configuration: `k8s.yaml`

### Key Components in `k8s.yaml`:
1. **Ingress NGINX Controller**:
   - Manages incoming traffic and routes HTTPS traffic to `myservice`.
   - Configured to use SSL/TLS termination and enforce mTLS (mutual tls).

2. **Service and Deployment for `myservice`**:
   - Defines a Deployment and a Service for `myservice`.
   - Configured to listen on port 8443 and use the generated certificates for secure communication.

**Note**: The Ingress is configured to handle HTTPS and requires client certificates for mTLS authentication.

---

## Myservice `main.py`: Custom HTTPS Service

**Purpose**: A simple FastaAPI HTTPS-enabled service.
- parses `secrets.json` file provided by the Vault injector.
- Uses `ssl` for handling secure connections.
- Serves requests over HTTPS.

### Dockerfile
The `main.py` is packaged in a Docker image using the provided `Dockerfile`.

---

## Running and Verifying the Setup
1. Run `make up` to deploy everything.
2. Use the provided `curl` command to test secure access to `myservice`.
3. Check the status of your services and pods using `kubectl`:
   ```bash
   kubectl get pods
   kubectl get services
   kubectl get ingress
   kubectl logs -l app=myservice -f
   ```
4. Access endpoint by providing client certificate, key and CA file
```bash
curl --cacert ./certs/ca.crt \
     --cert ./certs/client.crt \
     --key ./certs/client.key \
     https://myservice.example.com/
```
