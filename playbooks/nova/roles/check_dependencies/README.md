# Role: check_dependencies

This role ensures that Keystone and Glance services are available and responsive before Nova installation proceeds.

## Tasks:
- Authenticates against Keystone v3
- Extracts token
- Uses token to verify Glance service availability

## Variables:
Override via `group_vars/controller.yml` or env vars:
- `keystone_url`
- `keystone_user`
- `keystone_password`
- `keystone_project`

## Failures:
- Aborts play early if services are unavailable.
