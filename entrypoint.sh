#!/usr/bin/env bash
set -euo pipefail

LDAP_BASE_DN=${LDAP_BASE_DN:-dc=ds551,dc=edu}
LDAP_ROOT_DN=${LDAP_ROOT_DN:-cn=admin,${LDAP_BASE_DN}}
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-changeme}
LDAP_DATA_DIR=${LDAP_DATA_DIR:-/var/lib/openldap/openldap-data}
LDAP_SEED_LDIF=${LDAP_SEED_LDIF:-/ldif/seed.ldif}
LDAP_PORT=${LDAP_PORT:-3389}
LDAP_LOG_LEVEL=${LDAP_LOG_LEVEL:-256}

# Ensure writable directories for arbitrary UIDs
mkdir -p "${LDAP_DATA_DIR}" /tmp /ldif
chmod -R 777 "${LDAP_DATA_DIR}" /tmp /ldif

# Generate root password hash
ROOTPW_HASH=$(slappasswd -s "${LDAP_ADMIN_PASSWORD}")

# Render slapd.conf (kept in /tmp so arbitrary UIDs can write)
SLAPD_CONF="/tmp/slapd.conf"
cat > "${SLAPD_CONF}" <<EOF
include /etc/ldap/schema/core.schema
include /etc/ldap/schema/cosine.schema
include /etc/ldap/schema/inetorgperson.schema
include /etc/ldap/schema/nis.schema

pidfile /tmp/slapd.pid
argsfile /tmp/slapd.args
loglevel ${LDAP_LOG_LEVEL}

database mdb
maxsize 1073741824
suffix "${LDAP_BASE_DN}"
rootdn "${LDAP_ROOT_DN}"
rootpw ${ROOTPW_HASH}
directory ${LDAP_DATA_DIR}
index objectClass eq
EOF

# Seed only if the database is empty
if [ -d "${LDAP_DATA_DIR}" ] && [ -z "$(ls -A "${LDAP_DATA_DIR}" 2>/dev/null)" ] && [ -f "${LDAP_SEED_LDIF}" ]; then
  echo "Seeding LDAP database from ${LDAP_SEED_LDIF}"
  slapadd -f "${SLAPD_CONF}" -l "${LDAP_SEED_LDIF}"
else
  echo "Skipping seed (database not empty or seed file missing)"
fi

echo "Starting slapd on port ${LDAP_PORT}"
exec /usr/sbin/slapd -f "${SLAPD_CONF}" -h "ldap://0.0.0.0:${LDAP_PORT}/" -d "${LDAP_LOG_LEVEL}"
