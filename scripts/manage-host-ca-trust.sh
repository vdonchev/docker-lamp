#!/bin/bash

set -e

ACTION="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CA_FILE="$BASE_DIR/config/apache/ssl/dev-ca.crt"
LINUX_CA_FILE="/usr/local/share/ca-certificates/docker-lamp-dev-ca.crt"

if [[ "$ACTION" != "install" && "$ACTION" != "remove" ]]; then
  echo "Usage: $0 install|remove" >&2
  exit 1
fi

if [[ ! -f "$CA_FILE" ]]; then
  echo "[error] $CA_FILE does not exist. Run make cert first." >&2
  exit 1
fi
command -v openssl >/dev/null 2>&1 || {
  echo "[error] OpenSSL is required to validate the CA certificate." >&2
  exit 1
}
openssl x509 -in "$CA_FILE" -noout >/dev/null 2>&1 || {
  echo "[error] The local CA certificate cannot be parsed." >&2
  exit 1
}
if [[ "$ACTION" == "install" ]]; then
  openssl x509 -in "$CA_FILE" -noout -checkend 0 >/dev/null 2>&1 || {
    echo "[error] The local CA certificate is expired." >&2
    exit 1
  }
  openssl verify -CAfile "$CA_FILE" "$CA_FILE" >/dev/null 2>&1 || {
    echo "[error] The local CA certificate is not validly self-signed." >&2
    exit 1
  }
  CA_DETAILS="$(openssl x509 -in "$CA_FILE" -noout -text)"
  grep -q 'CA:TRUE' <<< "$CA_DETAILS" && grep -q 'Certificate Sign' <<< "$CA_DETAILS" || {
    echo "[error] Refusing to trust a certificate without CA signing constraints." >&2
    exit 1
  }
fi

FINGERPRINT="$(openssl x509 -in "$CA_FILE" -noout -fingerprint -sha256 | cut -d= -f2)"
echo "Docker LAMP development CA SHA256 fingerprint:"
echo "  $FINGERPRINT"

if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
  command -v powershell.exe >/dev/null 2>&1 || {
    echo "[error] powershell.exe is required to manage the Windows trust store from WSL." >&2
    exit 1
  }
  command -v wslpath >/dev/null 2>&1 || {
    echo "[error] wslpath is required to pass the CA path to Windows." >&2
    exit 1
  }
  WINDOWS_SCRIPT="$(wslpath -w "$SCRIPT_DIR/manage-windows-ca-trust.ps1")"
  WINDOWS_CA="$(wslpath -w "$CA_FILE")"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WINDOWS_SCRIPT" -Action "$ACTION" -CertificatePath "$WINDOWS_CA"
  exit $?
fi

case "$(uname -s)" in
  Linux)
    command -v update-ca-certificates >/dev/null 2>&1 || {
      echo "[error] This Linux distribution does not provide update-ca-certificates." >&2
      echo "        Install/remove $CA_FILE using your distribution's trust-store tooling." >&2
      exit 1
    }
    if [[ "$ACTION" == "install" ]]; then
      read -r -p "Type TRUST to install this CA system-wide: " confirmation
      [[ "$confirmation" == "TRUST" ]] || { echo "[error] Trust installation cancelled." >&2; exit 1; }
      sudo install -m 0644 "$CA_FILE" "$LINUX_CA_FILE"
    else
      read -r -p "Type UNTRUST to remove the Docker LAMP CA: " confirmation
      [[ "$confirmation" == "UNTRUST" ]] || { echo "[error] Trust removal cancelled." >&2; exit 1; }
      sudo rm -f "$LINUX_CA_FILE"
    fi
    sudo update-ca-certificates --fresh
    ;;
  Darwin)
    KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
    SHA1="$(openssl x509 -in "$CA_FILE" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ':')"
    if [[ "$ACTION" == "install" ]]; then
      read -r -p "Type TRUST to install this CA in your login Keychain: " confirmation
      [[ "$confirmation" == "TRUST" ]] || { echo "[error] Trust installation cancelled." >&2; exit 1; }
      if security find-certificate -Z -a "$KEYCHAIN" 2>/dev/null | grep -q "$SHA1"; then
        echo "[OK] This exact CA is already installed in the login Keychain."
      else
        security add-trusted-cert -r trustRoot -k "$KEYCHAIN" "$CA_FILE"
      fi
    else
      read -r -p "Type UNTRUST to remove this exact CA from your login Keychain: " confirmation
      [[ "$confirmation" == "UNTRUST" ]] || { echo "[error] Trust removal cancelled." >&2; exit 1; }
      if security find-certificate -Z -a "$KEYCHAIN" 2>/dev/null | grep -q "$SHA1"; then
        security delete-certificate -Z "$SHA1" "$KEYCHAIN"
      else
        echo "[OK] This exact CA is not installed in the login Keychain."
      fi
    fi
    ;;
  *)
    echo "[error] Unsupported host OS. Trust $CA_FILE manually using your OS certificate manager." >&2
    exit 1
    ;;
esac

echo "[OK] Host CA trust ${ACTION} completed. Restart open browsers before testing."
