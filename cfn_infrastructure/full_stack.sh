#!/usr/bin/env bash

TEMPLATE=root_template.yaml
. .settings.config
METHOD=$1

_validate() {
	echo 'Validate stack...' packaged_$TEMPLATE
	aws cloudformation validate-template --template-body file://.packaged_$TEMPLATE
}

_packaging() {
  echo '...packaging and upload to S3.'
  aws cloudformation package --template-file $TEMPLATE --output-template .packaged_$TEMPLATE\
      --s3-bucket $cfn_deployment_bucket --s3-prefix $stack_name/nested
  aws s3 cp .packaged_$TEMPLATE s3://$cfn_deployment_bucket/$stack_name
}

_check_status() {
  echo $METHOD still in progress..
	aws cloudformation wait stack-$METHOD-complete --stack-name $stack_name
	echo Done.
}

_create_certificate() {
  echo 'Create certificate.. this can take some minutes'
	aws cloudformation create-stack --stack-name certificate-for-$stack_name \
	    --template-body file://network/certificate.yml --parameters ParameterKey=DomainName,ParameterValue=$domain_name \
      --region us-east-1 # specific regions available such as Virgina
  aws cloudformation wait stack-create-complete --stack-name certificate-for-$stack_name
  echo '.. certificate created. Creating recordsets...'
}

_validate_certificate() {
  cert_arn=$(aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='$domain_name'].CertificateArn" --output text)

  root_record_name=$(aws acm describe-certificate --certificate-arn $cert_arn --region us-east-1 \
    --query "Certificate.DomainValidationOptions[?DomainName=='$domain_name'].ResourceRecord.Name" --output text)
  root_record_value=$(aws acm describe-certificate --certificate-arn $cert_arn --region us-east-1 \
    --query "Certificate.DomainValidationOptions[?DomainName=='$domain_name'].ResourceRecord.Value" --output text)

  www_record_name=$(aws acm describe-certificate --certificate-arn $cert_arn --region us-east-1 \
    --query "Certificate.DomainValidationOptions[?DomainName=='www.$domain_name'].ResourceRecord.Name" --output text)
  www_record_value=$(aws acm describe-certificate --certificate-arn $cert_arn --region us-east-1 \
    --query "Certificate.DomainValidationOptions[?DomainName=='www.$domain_name'].ResourceRecord.Value" --output text)

  hosted_zone_id=$(aws route53  list-hosted-zones --query "HostedZones[?Name=='$domain_name.'].Id" \
    --output text | cut -d'/' -f 3)

  root_change_id=$(aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id \
    --change-batch '{ "Comment": "Create recordset", "Changes": [ { "Action": "CREATE",
      "ResourceRecordSet": { "Name": "'$root_record_name'", "Type": "CNAME", "TTL": 120,
      "ResourceRecords": [ { "Value": "'$root_record_value'" } ] } } ] }' \
    --query "ChangeInfo.Id" --output text)


  www_change_id=$(aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id \
    --change-batch '{ "Comment": "Create recordset", "Changes": [ { "Action": "CREATE",
      "ResourceRecordSet": { "Name": "'$www_record_name'", "Type": "CNAME", "TTL": 120,
      "ResourceRecords": [ { "Value": "'$www_record_value'" } ] } } ] }'\
    --query "ChangeInfo.Id" --output text)

  root_status="None"
  www_status="None"

  echo '.. waiting for record set changes.'
  while [[ $root_status != "INSYNC" && $www_status != "INSYNC" ]]; do
    root_status=$(aws route53 get-change --id $root_change_id --query "ChangeInfo.Status" --output text)
    www_status=$(aws route53 get-change --id $www_change_id --query "ChangeInfo.Status" --output text)
    sleep 10
    echo '...'
    echo 'Statuses Recordsets:' $root_status '  ' $www_status
  done

}


create() {
  _packaging
	_validate
  #_create_certificate

  echo 'Create stack resources..'
	aws cloudformation create-stack --stack-name $stack_name \
			--template-body file://.packaged_$TEMPLATE \
			--parameters ParameterKey=DomainName,ParameterValue=$domain_name
	_check_status
	_validate_certificate
}

delete() {
  aws cloudformation delete-stack --stack-name $stack_name
  _check_status
}

if [ "$METHOD" ]; then
	echo Starting to $METHOD stack..
fi

"$@"
