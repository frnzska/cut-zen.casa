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

create() {
  _packaging
	_validate
	echo 'Create stack'
	aws cloudformation create-stack --stack-name $stack_name \
			--template-body file://.packaged_$TEMPLATE \
			--parameters ParameterKey=DomainName,ParameterValue=$domain_name
	_check_status
}

delete() {
  aws cloudformation delete-stack --stack-name $stack_name
  _check_status
}

if [ "$METHOD" ]; then
	echo Starting to $METHOD stack..
fi

"$@"