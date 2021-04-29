#!/usr/bin/env bash

TEMPLATE=root_template.yaml
. .settings.config
METHOD=$1
end_color='\x1B[0m'
orange='\x1b[1;33m'
green='\x1b[0;32m'

_packaging() {
  echo -e "${green}...packaging and upload to S3.${end_color}"
  aws cloudformation package --template-file $TEMPLATE --output-template .packaged_$TEMPLATE \
      --s3-bucket $cfn_deployment_bucket --s3-prefix $stack_name/nested
  aws s3 cp .packaged_$TEMPLATE s3://$cfn_deployment_bucket/$stack_name
}

_validate() {
	echo -e "${green}Validate stack in ${end_color} .packaged_$TEMPLATE "
	aws cloudformation validate-template --template-body file://.packaged_$TEMPLATE
}

_check_status() {
  partial_stack=$1
  echo $partial_stack-$stack_name
  echo $partial_stack $METHOD still in progress..
	aws cloudformation wait stack-$METHOD-complete --stack-name $partial_stack-$stack_name
	echo Done.
}

_create_certificate() {
  echo -e "${green}Create certificate..${end_color}"
	aws cloudformation create-stack --stack-name certificate-for-$stack_name \
	    --template-body file://network/certificate.yml --parameters ParameterKey=DomainName,ParameterValue=$domain_name \
      --region us-east-1 # needs to be specific region such as us-east-1
  echo $cert_arn
}

_do_validation_record_for() {
  record_domain_name=$1
  action=$2

  cert_arn=$(aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='$domain_name'].CertificateArn" --output text)


  hosted_zone_id=$(aws route53  list-hosted-zones --query "HostedZones[?Name=='$domain_name.'].Id" \
    --output text | cut -d'/' -f 3)

  record_name=$(aws acm describe-certificate --certificate-arn $cert_arn --region us-east-1 \
    --query "Certificate.DomainValidationOptions[?DomainName=='$record_domain_name'].ResourceRecord.Name" --output text)
  record_value=$(aws acm describe-certificate --certificate-arn $cert_arn --region us-east-1 \
    --query "Certificate.DomainValidationOptions[?DomainName=='$record_domain_name'].ResourceRecord.Value" --output text)


  change_id=$(aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id \
    --change-batch '{ "Comment": "Create recordset", "Changes": [ { "Action": "'$action'",
      "ResourceRecordSet": { "Name": "'$record_name'", "Type": "CNAME", "TTL": 120,
      "ResourceRecords": [ { "Value": "'$record_value'" } ] } } ] }' \
    --query "ChangeInfo.Id" --output text)

  echo $change_id

}

_validate_certificate() {
  root_change_id=$(_do_validation_record_for $domain_name "CREATE")
  www_change_id=$(_do_validation_record_for www.$domain_name "CREATE")
  root_status="Init" www_status="Init"

  echo -e "${green} Validation in progress.. waiting for record set changes.${end_color}"
  while [[ $root_status != "INSYNC" && $www_status != "INSYNC" ]]; do
    root_status=$(aws route53 get-change --id $root_change_id --query "ChangeInfo.Status" --output text)
    www_status=$(aws route53 get-change --id $www_change_id --query "ChangeInfo.Status" --output text)
    sleep 10
    echo '...'
    echo 'Status Recordsets:' $root_status '  ' $www_status
  done
}

_create_and_wait_for_hosted_zone() {
  echo -e "${green} Create hosted_zone ${end_color}"
  aws cloudformation create-stack --stack-name hosted-zone-$stack_name \
	    --template-body file://network/hosted_zone.yml --parameters ParameterKey=DomainName,ParameterValue=$domain_name
  aws cloudformation wait stack-create-complete --stack-name hosted-zone-$stack_name
}

create() {
  _packaging
	_validate

  echo 'Create stack resources.. takes around 30 min.'
  _create_certificate
  _create_and_wait_for_hosted_zone

  echo -e "${orange} ACTION REQUIRED: Add name server to your domain registrar.${end_color}"

  _validate_certificate
  certificate_arn=$(aws acm list-certificates --region us-east-1 \
      --query "CertificateSummaryList[?DomainName=='$domain_name'].CertificateArn" --output text)

  echo 'Waiting for AWS to validate certificate.. might take a bit.'
  aws cloudformation wait stack-create-complete --stack-name certificate-for-$stack_name --region us-east-1

	aws cloudformation create-stack --stack-name $stack_name \
			--template-body file://.packaged_$TEMPLATE \
			--parameters ParameterKey=DomainName,ParameterValue=$domain_name ParameterKey=CertificateArn,ParameterValue=$certificate_arn
	aws cloudformation wait stack-create-complete --stack-name $stack_name
  echo 'Create stack done.'
}

delete() {
  echo "Delete resources"
  _do_validation_record_for $domain_name "DELETE"
  _do_validation_record_for www.$domain_name "DELETE"

  echo "Delete Bucket contents"
  aws s3 rm s3://logs.${domain_name} --recursive
  aws s3 rm s3://${domain_name} --recursive
  aws s3 rm s3://www.${domain_name} --recursive

  aws cloudformation delete-stack --stack-name $stack_name
  aws cloudformation wait stack-delete-complete --stack-name $stack_name

  aws cloudformation delete-stack --stack-name certificate-for-$stack_name --region us-east-1

  aws cloudformation delete-stack --stack-name hosted-zone-$stack_name
  aws cloudformation wait stack-delete-complete --stack-name hosted-zone-$stack_name
}

if [ "$METHOD" ]; then
	echo Starting to $METHOD stack..
fi

"$@"
