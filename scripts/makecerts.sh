#!/bin/bash

set -e

certs_dir="certs"
base_domain="example.com"
company="Tronius"

mkdir -p $certs_dir && cd $certs_dir

# CA key
openssl genrsa -out ca.key 2048

# client key
openssl genrsa -out client.key 2048

# CA
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt \
    -subj "/CN=$base_domain CA/O=$company."

# server key
openssl genrsa -out server.key 2048

# server CSR
openssl req -new -key server.key -out server.csr \
    -subj "/CN=$base_domain/O=$company."

# server cert
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt -days 365 \
    -sha256 -extfile ../server.ext

# client csr
openssl req -new -key client.key -out client.csr \
    -subj "/CN=client/O=$company."

# client cert
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out client.crt -days 365 -sha256
