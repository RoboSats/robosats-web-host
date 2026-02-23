#!/bin/bash
set -e

COOKIE_FILE="/var/lib/tor/control_auth_cookie"
KEY_DIR="/var/lib/onionbalance"
CONFIG_FILE="/etc/onionbalance/config.yaml"

echo "[onionbalance] Waiting for Tor ControlPort cookie to be available..."
until [ -f "$COOKIE_FILE" ]; do
    sleep 2
done
echo "[onionbalance] Tor cookie file found."

# Generate frontend key on first run if no .key file exists yet
if ! ls "$KEY_DIR"/*.key 2>/dev/null | grep -q .; then
    echo "[onionbalance] No frontend key found. Generating new onion identity..."
    python3 - <<'PYEOF'
import os
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
import hashlib, base64, struct

KEY_DIR = "/var/lib/onionbalance"
os.makedirs(KEY_DIR, exist_ok=True)

# Generate Ed25519 private key
private_key = Ed25519PrivateKey.generate()
public_key = private_key.public_key()

pub_bytes = public_key.public_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PublicFormat.Raw
)

# Derive v3 onion address: base32( pubkey || checksum || version )
version = b"\x03"
checksum_material = b".onion checksum" + pub_bytes + version
checksum = hashlib.sha3_256(checksum_material).digest()[:2]
addr_bytes = pub_bytes + checksum + version
onion_address = base64.b32encode(addr_bytes).decode().lower()

# Write PEM private key (OBv3 format)
key_fname = os.path.join(KEY_DIR, "{}.key".format(onion_address))
pem_bytes = private_key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption()
)
with open(key_fname, "wb") as f:
    f.write(pem_bytes)
os.chmod(key_fname, 0o600)

# Save hostname for reference
with open(os.path.join(KEY_DIR, "hostname"), "w") as f:
    f.write(onion_address + ".onion\n")

print("[onionbalance] Generated new frontend onion address: {}.onion".format(onion_address))
print("[onionbalance] Key written to: {}".format(key_fname))
PYEOF
else
    ADDR=$(ls "$KEY_DIR"/*.key | head -1 | xargs basename | sed 's/\.key$//')
    echo "[onionbalance] Using existing frontend key for: ${ADDR}.onion"
fi

# Print the frontend address clearly
if [ -f "$KEY_DIR/hostname" ]; then
    echo ""
    echo "=========================================="
    echo "  Frontend .onion address:"
    echo "  $(cat $KEY_DIR/hostname)"
    echo "=========================================="
    echo ""
fi

# Determine the key file path and update config with the correct absolute key path
KEY_FILE=$(ls "$KEY_DIR"/*.key | head -1)

# Patch the config to use the correct absolute key path
CONFIG_TEMP=$(mktemp)
sed "s|__KEY_FILE__|${KEY_FILE}|g" "$CONFIG_FILE" > "$CONFIG_TEMP"

echo "[onionbalance] Starting onionbalance..."
exec onionbalance \
    --config "$CONFIG_TEMP" \
    --ip 127.0.0.1 \
    --port 9051 \
    -v info
