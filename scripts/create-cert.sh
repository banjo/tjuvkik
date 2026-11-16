#!/bin/sh
# Creates the self-signed "Tjuvkik Dev" code signing certificate in the login keychain.
# Signing every build with the same certificate keeps Input Monitoring granted across rebuilds.
set -eu

name="Tjuvkik Dev"
if security find-certificate -c "$name" >/dev/null 2>&1; then
  echo "$name already exists"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=$name" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false" \
  -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null

# macOS's importer only reads the legacy PKCS#12 encryption.
openssl pkcs12 -export -legacy -passout pass:tjuvkik \
  -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/cert.p12"

security import "$tmp/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
  -P tjuvkik -T /usr/bin/codesign
echo "Created $name"
