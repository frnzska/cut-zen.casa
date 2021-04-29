# Description
Infrastructure to serve _yourDomain_ from s3 using Cloudfront. Redirects http request to https. 
Serving both
- _yourDomain_ e.g. example.com 
- _www.yourDomain_ e.g. www.example.com

## Requirements
- AWS credentials configured, permissions to create related resources.

## Creates
in your default region
- S3 Buckets: yourDomain,  www.yourDomain and logs.yourDomain
- DNS records
- Certificate (in region us-east-1)
- Cloudfront Distribution

## Setup
1. Fill out .settings.config file.

2. Generate infrastructure with 
`bash full_stack.sh create`.
   
3. Add nameservers to your domain registrar. 

- Delete infrastructure with 
`bash scripts/full_stack.sh delete`.
