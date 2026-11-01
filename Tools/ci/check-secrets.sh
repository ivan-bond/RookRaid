#!/bin/bash
# Fails when a secret is tracked. Config/Secrets.xcconfig stays local (see .gitignore).
set -euo pipefail

if git ls-files --error-unmatch Config/Secrets.xcconfig >/dev/null 2>&1; then
  echo "Config/Secrets.xcconfig is tracked. It belongs only on the machine that builds the app."
  exit 1
fi

if git grep -n -E -e '-----BEGIN (RSA |OPENSSH |EC |PGP )?PRIVATE KEY-----' -- . ':!.git' >/dev/null; then
  echo "A private key is tracked:"
  git grep -n -E -e '-----BEGIN (RSA |OPENSSH |EC |PGP )?PRIVATE KEY-----' -- . ':!.git'
  exit 1
fi

# Supabase service-role keys and other JWTs. The word service_role in SQL is a Postgres role, not a key.
if git grep -n -E -e 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}' -- . ':!.git' >/dev/null; then
  echo "A JWT-shaped token is tracked:"
  git grep -n -E -e 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}' -- . ':!.git'
  exit 1
fi

if git grep -n -E -e 'sb_secret_[A-Za-z0-9_-]{10,}' -- . ':!.git' >/dev/null; then
  echo "A Supabase secret key is tracked:"
  git grep -n -E -e 'sb_secret_[A-Za-z0-9_-]{10,}' -- . ':!.git'
  exit 1
fi

echo "No tracked secrets found."
