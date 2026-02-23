## OnionBalance — Load Balancing across multiple Tor Hidden Services

This repo includes an [OnionBalance](https://gitlab.torproject.org/tpo/onion-services/onionbalance) service that load-balances traffic across multiple backend `.onion` instances exposing the same RoboSats frontend.

### Architecture

```
[User] → [Frontend .onion (OnionBalance)] → [Backend 1 .onion]
                                           → [Backend 2 .onion]
                                           → [Backend N .onion]
```

OnionBalance merges the introduction points of all backend instances into a single frontend descriptor, giving users one stable `.onion` address while distributing the load.

### Configuration

Backend instances are configured in `onionbalance/config/config.yaml`. Edit the `instances` list to add or remove backends.

### First Run — Generating the Frontend Key

On the first `docker compose up`, the `onionbalance` container will automatically:
1. Generate a new Ed25519 private key for the frontend `.onion` address
2. Save it to `./onionbalance/data/<address>.key` (persisted via Docker volume)
3. Save the frontend `.onion` address to `./onionbalance/data/hostname`

To see the generated frontend `.onion` address:

```bash
docker compose logs onionbalance | grep -A3 "Frontend .onion address"
# or
cat ./onionbalance/data/hostname
```

### Using an Existing Frontend Key

If you already have an Ed25519 private key you want to use as the frontend:

- **OBv3 PEM format** (preferred): Place it as `./onionbalance/data/<address>.key`
- **Tor binary format** (`hs_ed25519_secret_key`): Place it as `./onionbalance/data/<address>.key` — onionbalance will detect the format automatically

### Backend Instance Requirements

Each backend `.onion` instance must have its Tor hidden service configured with:
```
HiddenServiceVersion 3
```
The backend instances do **not** need any special onionbalance configuration — they just need to be running normally.

### Updating Backend Instances

Edit `onionbalance/config/config.yaml` and restart the service:
```bash
docker compose restart onionbalance
```
