---
bump: patch
type: fix
---

Use the CA certificate configured in `APPSIGNAL_CA_FILE_PATH` to download the
AppSignal agent when installing this gem.

The gem downloads the agent from our servers over HTTPS during installation. It
always used the CA certificate bundled with the gem to verify that connection,
whatever the value of the `ca_file_path` configuration option. This meant the
installation failed behind a proxy that intercepts TLS connections, such as
Zscaler, even when `APPSIGNAL_CA_FILE_PATH` pointed to a CA bundle that trusts
the proxy.

The bundled CA certificate is still used when `APPSIGNAL_CA_FILE_PATH` is not
set.

Thanks @Cosmo for your contribution!
