# Description
Infrastructure to serve https _yourDomain_ from s3 using Cloudfront.

# Requirements
- AWS credentials configured and permissions set

# Creates
in your default region
- S3 Buckets: yourDomain,  www.yourDomain and logs.yourDomain
- DNS, DNSRecords
- Certificate (in region us-east-1)
- Cloudfront Distribution


# Setup
1. Fill out .settings.config file.

2. Generate infrastructure with 
`bash full_stack.sh create`.
   
3. Add nameservers to your domain registrar. 

- Delete infrastructure with 
`bash scripts/full_stack.sh delete`.
