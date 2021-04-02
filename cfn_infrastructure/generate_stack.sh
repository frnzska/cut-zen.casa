
TEMPLATE=file://$2
DOMAIN_NAME=testcut-zen.casa
STACK_NAME=testcut-zencasa-buckets-stack # no special characters except dash allowed

_validate() {
	echo 'Validate stack...' $TEMPLATE
	aws cloudformation validate-template --template-body $TEMPLATE
}

create() {
	_validate
	echo 'Create stack'
	aws cloudformation create-stack --stack-name $STACK_NAME \
			--template-body $TEMPLATE \
			--parameters ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME

	#check_status
    echo .. $method still in progress.
	aws cloudformation wait stack-create-complete --stack-name $STACK_NAME
	echo 'Done'
}

delete() {
    aws cloudformation delete-stack --stack-name $STACK_NAME
    #check_status
    echo .. delete still in progress.
	aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME
	echo 'Done'
}

if [ "$method" ]; then
	echo doing $method stack
fi

"$@"
