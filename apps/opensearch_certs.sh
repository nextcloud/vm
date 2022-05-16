#!/bin/sh
# Create TLS self-signed CA certificates for 5 years required to comply
# with transport security layer requirement.
# Source:
# https://opensearch.org/docs/latest/security-plugin/configuration/generate-certificates/#sample-script

mkdir -p tls_store
TLS_DN="/C=CA/ST=NEXTCLOUD/L=VM/O=OPENSEARCH/OU=FTS"

# Root CA
openssl genrsa -out root-ca-key.pem 4096
openssl req -new -x509 -sha256 -key root-ca-key.pem -subj "${TLS_DN}/CN=ROOT" -out root-ca.pem -days 1825
# Admin cert
openssl genrsa -out admin-key-temp.pem 4096
openssl pkcs8 -inform PEM -outform PEM -in admin-key-temp.pem -topk8 -nocrypt -v1 PBE-SHA1-3DES -out admin-key.pem
openssl req -new -key admin-key.pem -subj "${TLS_DN}/CN=ADMIN" -out admin.csr
openssl x509 -req -in admin.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -sha256 -out admin.pem -days 1825
# Node cert
openssl genrsa -out node-key-temp.pem 4096
openssl pkcs8 -inform PEM -outform PEM -in node-key-temp.pem -topk8 -nocrypt -v1 PBE-SHA1-3DES -out node-key.pem
openssl req -new -key node-key.pem -subj "${TLS_DN}/CN=__NCDOMAIN__" -out node.csr
openssl x509 -req -in node.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -sha256 -out node.pem -days 1825
# Client cert
openssl genrsa -out client-key-temp.pem 4096
openssl pkcs8 -inform PEM -outform PEM -in client-key-temp.pem -topk8 -nocrypt -v1 PBE-SHA1-3DES -out client-key.pem
openssl req -new -key client-key.pem -subj "${TLS_DN}/CN=CLIENT" -out client.csr
openssl x509 -req -in client.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -sha256 -out client.pem -days 1825

# Cleanup
rm admin-key-temp.pem \
   admin.csr \
   node-key-temp.pem \
   node.csr \
   client-key-temp.pem \
   client.csr

# Store
mv client.pem \
   client-key.pem \
   root-ca-key.pem -t tls_store

# openssl 3.0 workaround
if [ "$(lsb_release -sr)" = "20.04" ]; then
   mv root-ca.srl tls_store
fi
