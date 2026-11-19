#!/bin/bash
# Lab helper: create a self-signed root CA and intermediate CA for Azure Firewall
# Premium TLS inspection. Adapted from Microsoft's published test scripts at
# https://learn.microsoft.com/en-us/azure/firewall/premium-certificates
# For production, use your corporate PKI instead of this test CA.
set -euo pipefail
cd "$(dirname "$0")"

openssl req -x509 -new -nodes -newkey rsa:4096 -keyout rootCA.key -sha256 -days 1024 -out rootCA.crt -subj "/C=US/ST=US/O=Self Signed/CN=Self Signed Root CA" -config openssl.cnf -extensions rootCA_ext
openssl req -new -nodes -newkey rsa:4096 -keyout interCA.key -sha256 -out interCA.csr -subj "/C=US/ST=US/O=Self Signed/CN=Self Signed Intermediate CA"
openssl x509 -req -in interCA.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out interCA.crt -days 1024 -sha256 -extfile openssl.cnf -extensions interCA_ext
openssl pkcs12 -export -out interCA.pfx -inkey interCA.key -in interCA.crt -password "pass:"

echo
echo "Generated lab certificates (do not commit the keys or PFX):"
echo "  rootCA.crt / rootCA.key  — install rootCA.crt on test clients"
echo "  interCA.crt / interCA.key"
echo "  interCA.pfx              — set intermediate_ca_pfx_path to this file"
