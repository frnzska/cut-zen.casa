#!/usr/bin/env bash

TEMPLATE=root_template.yaml
eval $(scripts/parse_yaml config.yaml)
DOMAIN_NAME=$domain_name
STACK_NAME=$domain_name-stack # no special characters except dash allowed
CFN_DEPLOYMENT_BUCKET=franziska-adler-deployments
METHOD=$1

_validate() {
	echo 'Validate stack...' packaged_$TEMPLATE
	aws cloudformation validate-template --template-body file://.packaged_$TEMPLATE
}

_packaging() {
  echo '...packaging and upload to S3.'
  aws cloudformation package --template-file $TEMPLATE --output-template .packaged_$TEMPLATE\
      --s3-bucket $CFN_DEPLOYMENT_BUCKET --s3-prefix $STACK_NAME/nested
  aws s3 cp .packaged_$TEMPLATE s3://$CFN_DEPLOYMENT_BUCKET/$STACK_NAME
}

_check_status() {
  echo $METHOD still in progress..
	aws cloudformation wait stack-$METHOD-complete --stack-name $STACK_NAME
	echo Done.
}

create() {
  _packaging
	_validate
	echo 'Create stack'
	aws cloudformation create-stack --stack-name $STACK_NAME \
			--template-body file://.packaged_$TEMPLATE \
			--parameters ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME
	_check_status
}

delete() {
  aws cloudformation delete-stack --stack-name $STACK_NAME
  _check_status
}

if [ "$METHOD" ]; then
	echo Starting to $METHOD stack..
fi

"$@"
