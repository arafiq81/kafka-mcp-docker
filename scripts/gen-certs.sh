#!/bin/bash
set -e

CERT_DIR="$(cd "$(dirname "$0")/../docker/certs" && pwd)"
PASS="changeit"

mkdir -p "$CERT_DIR"

# CA
if [ ! -f "$CERT_DIR/ca.key" ]; then
  openssl genrsa -out "$CERT_DIR/ca.key" 4096
  openssl req -x509 -new -nodes -key "$CERT_DIR/ca.key" -sha256 -days 3650 \
    -subj "/CN=Kafka-POC-CA" -out "$CERT_DIR/ca.crt"
fi

# Truststore (global copy)
keytool -import -alias CARoot -file "$CERT_DIR/ca.crt" \
  -keystore "$CERT_DIR/kafka.truststore.jks" -storepass "$PASS" -noprompt

# Client cert/keystore for mTLS
CLIENT_DIR="$CERT_DIR/client"
mkdir -p "$CLIENT_DIR"
keytool -genkeypair -alias "client" -keyalg RSA -keysize 2048 \
  -keystore "$CLIENT_DIR/client.keystore.jks" -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=client" -validity 3650
keytool -certreq -alias "client" -file "$CLIENT_DIR/client.csr" \
  -keystore "$CLIENT_DIR/client.keystore.jks" -storepass "$PASS"
openssl x509 -req -in "$CLIENT_DIR/client.csr" -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
  -CAcreateserial -out "$CLIENT_DIR/client.crt" -days 3650 -sha256 \
  -extfile <(printf "subjectAltName=DNS:%s" "client")
keytool -import -alias CARoot -file "$CERT_DIR/ca.crt" \
  -keystore "$CLIENT_DIR/client.keystore.jks" -storepass "$PASS" -noprompt
keytool -import -alias "client" -file "$CLIENT_DIR/client.crt" \
  -keystore "$CLIENT_DIR/client.keystore.jks" -storepass "$PASS" -noprompt
keytool -import -alias CARoot -file "$CERT_DIR/ca.crt" \
  -keystore "$CLIENT_DIR/kafka.truststore.jks" -storepass "$PASS" -noprompt

for broker in kafka1 kafka2 kafka3; do
  BROKER_DIR="$CERT_DIR/$broker"
  mkdir -p "$BROKER_DIR"

  # Per-broker truststore
  keytool -import -alias CARoot -file "$CERT_DIR/ca.crt" \
    -keystore "$BROKER_DIR/kafka.truststore.jks" -storepass "$PASS" -noprompt

  # Keystore
  keytool -genkeypair -alias "$broker" -keyalg RSA -keysize 2048 \
    -keystore "$BROKER_DIR/${broker}.keystore.jks" -storepass "$PASS" -keypass "$PASS" \
    -dname "CN=${broker}" -ext "SAN=DNS:${broker}" -validity 3650

  # CSR
  keytool -certreq -alias "$broker" -file "$BROKER_DIR/${broker}.csr" \
    -keystore "$BROKER_DIR/${broker}.keystore.jks" -storepass "$PASS"

  # Sign cert
  openssl x509 -req -in "$BROKER_DIR/${broker}.csr" -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial -out "$BROKER_DIR/${broker}.crt" -days 3650 -sha256 \
    -extfile <(printf "subjectAltName=DNS:%s" "$broker")

  # Import CA and signed cert into keystore
  keytool -import -alias CARoot -file "$CERT_DIR/ca.crt" \
    -keystore "$BROKER_DIR/${broker}.keystore.jks" -storepass "$PASS" -noprompt
  keytool -import -alias "$broker" -file "$BROKER_DIR/${broker}.crt" \
    -keystore "$BROKER_DIR/${broker}.keystore.jks" -storepass "$PASS" -noprompt

  # Copy client certs into each broker folder (for CLI inside container)
  mkdir -p "$BROKER_DIR/client"
  cp -f "$CLIENT_DIR/client.keystore.jks" "$BROKER_DIR/client/client.keystore.jks"
  cp -f "$CLIENT_DIR/kafka.truststore.jks" "$BROKER_DIR/client/kafka.truststore.jks"

done

echo "Certificates generated in $CERT_DIR"
