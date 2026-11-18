#!/bin/sh
# Puts the self-signed "Tjuvkik" code signing certificate in the login keychain.
# Every release is signed with it, so macOS keeps Input Monitoring granted across updates.
#
#   scripts/create-cert.sh                 create a new certificate and write a backup
#   scripts/create-cert.sh Tjuvkik.p12     import a backup (asks for its password)
set -eu

name="Tjuvkik"
keychain="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -a -c "$name" "$keychain" 2>/dev/null | grep -q "\"$name\""; then
  echo "$name already exists"
  exit 0
fi

if [ $# -gt 0 ]; then
  printf "Password for %s: " "$1"
  stty -echo
  read -r password
  stty echo
  echo
  security import "$1" -k "$keychain" -P "$password" -T /usr/bin/codesign
  echo "Imported $name"
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

password=$(openssl rand -base64 24)
backup="$HOME/Downloads/$name.p12"

# macOS's importer only reads the legacy PKCS#12 encryption.
openssl pkcs12 -export -legacy -passout "pass:$password" \
  -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$backup"

security import "$backup" -k "$keychain" -P "$password" -T /usr/bin/codesign
echo "Created $name"
echo
echo "Backup: $backup"
echo "Password: $password"
echo
echo "Store both in your password manager, then delete the file."
echo "Losing it means every user has to grant Input Monitoring again."
