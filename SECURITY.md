# Security

## Repository policy

Never commit:
- AWS credentials or tokens;
- SSH private keys;
- JWT signing secrets;
- database passwords;
- real passenger/customer data;
- real personal contact information;
- `.env` files;
- backup archives or application logs.

## Runtime secrets

The application requires secrets at runtime:

- `JWT_SECRET`
- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`

Use a local `.env` only for development. In AWS, prefer Secrets Manager or Systems Manager Parameter Store.

## Network boundary

The intended Compose topology does not publish MongoDB or the admin Express API to the host. The admin Nginx service is the only host-published internal UI endpoint in the local demo topology.

For an AWS deployment, the internal tier should be reachable only through a private access path such as VPN, SSM Session Manager, or controlled private networking.

## Demo data

Use fictional/demo reservation and passenger information only.
