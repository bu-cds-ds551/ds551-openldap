# ds551-openldap

OpenShift-friendly OpenLDAP image for DS-551. Runs under arbitrary UIDs (restricted-v2 SCC) and listens on a non-privileged port (default 3389) so it can be fronted by a Service on port 389.

## Features
- Works with arbitrary UIDs (no fixed `chown` needed; writable paths are world-writable for class use).
- Default LDAP tree: `dc=ds551,dc=edu` with admin `cn=admin,dc=ds551,dc=edu`.
- Seeds data from an LDIF mounted at `/ldif/seed.ldif` (configurable).
- Non-privileged listen port (`LDAP_PORT`, default 3389) so Services can map 389 → 3389.

## Environment Variables
- `LDAP_BASE_DN` (default `dc=ds551,dc=edu`)
- `LDAP_ROOT_DN` (default `cn=admin,${LDAP_BASE_DN}`)
- `LDAP_ADMIN_PASSWORD` (default `changeme`)
- `LDAP_DATA_DIR` (default `/var/lib/openldap/openldap-data`)
- `LDAP_SEED_LDIF` (default `/ldif/seed.ldif`)
- `LDAP_PORT` (default `3389`)
- `LDAP_LOG_LEVEL` (default `256`)

## Build
```sh
docker build -t bu-cds-ds551/ds551-openldap:latest .
```

## Local Run (for smoke test)
```sh
docker run --rm -p 1389:3389 \
  -e LDAP_ADMIN_PASSWORD=changeme-ldap \
  bu-cds-ds551/ds551-openldap:latest

# Then in another shell:
ldapsearch -x -H ldap://localhost:1389 -D "cn=admin,dc=ds551,dc=edu" -w changeme-ldap -b "dc=ds551,dc=edu"
```

## OpenShift Deployment Example
Service maps 389 to the container’s 3389:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ldap-seed
data:
  seed.ldif: |
    # replace with your course LDIF
    dn: dc=ds551,dc=edu
    objectClass: top
    objectClass: dcObject
    objectClass: organization
    o: DS551
    dc: ds551

    dn: ou=people,dc=ds551,dc=edu
    objectClass: top
    objectClass: organizationalUnit
    ou: people
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ds551-ldap
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ds551-ldap
  template:
    metadata:
      labels:
        app: ds551-ldap
    spec:
      containers:
        - name: ldap
          image: quay.io/langdon/ds551-openldap:latest
          ports:
            - containerPort: 3389
              name: ldap
          env:
            - name: LDAP_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ldap-admin
                  key: LDAP_ADMIN_PASSWORD
            - name: LDAP_SEED_LDIF
              value: /ldif/seed.ldif
          volumeMounts:
            - name: seed
              mountPath: /ldif
      volumes:
        - name: seed
          configMap:
            name: ldap-seed
---
apiVersion: v1
kind: Service
metadata:
  name: ldap
spec:
  selector:
    app: ds551-ldap
  ports:
    - name: ldap
      port: 389
      targetPort: 3389
```

## Notes
- Writable paths (`/var/lib/openldap/openldap-data`, `/tmp`, `/ldif`) are world-writable to support arbitrary UIDs; acceptable for class use only.
- Seed import runs only when the data directory is empty.
- The image does not start TLS; run behind an internal Service and use network policy for isolation.
- Sample `ldif/seed.ldif` uses placeholder passwords; replace with cohort-specific LDIF (and update NiFi bind credentials) before deploying.
- Base image: `debian:bookworm-slim` to avoid RHEL entitlements while keeping a minimal userspace.
- No fixed `USER` in the image—OpenShift will inject an allowed UID from the project range (required for restricted-v2).
