# Description
Infrastructure to serve https _Some_Domain_ from s3.

# Requirements
- AWS credentials configured and permissions set

# Creates
mainly in your default region
- S3 Buckets
- DNS, DNSRecords
- Certificate (in region us-east-1)
- Cloudfront Distribution


# Setup
1. Fill out .settings.config file.

2. Generate infrastructure with 
`bash scripts/full_stack.sh create`.
   
3. Add nameservers to your domain registrar. 

5. Deploy Application TODO

- Delete infrastructure with 
`bash scripts/full_stack.sh delete`.
