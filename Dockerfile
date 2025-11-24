FROM debian:bookworm-slim

ENV LDAP_BASE_DN="dc=ds551,dc=edu" \
    LDAP_ROOT_DN="cn=admin,dc=ds551,dc=edu" \
    LDAP_ADMIN_PASSWORD="changeme" \
    LDAP_DATA_DIR="/var/lib/openldap/openldap-data" \
    LDAP_SEED_LDIF="/ldif/seed.ldif" \
    LDAP_PORT="3389" \
    LDAP_LOG_LEVEL="256"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      slapd ldap-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /ldif "${LDAP_DATA_DIR}" /tmp && \
    chmod -R 777 /ldif "${LDAP_DATA_DIR}" /tmp

COPY entrypoint.sh /entrypoint.sh
COPY ldif/seed.ldif /ldif/seed.ldif
RUN chmod +x /entrypoint.sh

EXPOSE 3389
ENTRYPOINT ["/entrypoint.sh"]
