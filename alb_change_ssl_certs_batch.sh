#!/bin/bash

# AWS ALB - Change All port 443 HTTPS Protocol ALB Listeners SSL Certificate to new one of either IAM or ACM source 
## Useful when you have old IAM SSL Cert installed and want to migrate to ACM. Or you just want to use completely different SSL Certificate.

# envs
LOG_FILE="alb_update.log"
NEW_SSL_CERT_EXP_DATE="1612340000.0" # result of -> aws --region $REGION acm describe-certificate --certificate-arn <ACM_ARN_OF_NEW_SSL_CERT> --query 'Certificate.NotAfter'
#date -d @1612340000.0  --> "Wed Feb  3 08:13:20 UTC 2021"
IAM_SSL_CERT="arn:aws:iam::<aws_root_account_id>:server-certificate/<iam_ssl_cert_name>"
SSL_CERT_DOMAIN_NAME="<domain_name_of_ssl_cert>" # i.e. "blabla.com" or wildcard "*.blabla.com"

# Using IAM or ACM based SSL Cert?
echo "IAM SSL Cert or ACM SSL Cert? [iam/acm]"
read r
if   [[ "$r" == "iam" ]]; then
    NEW_SSL_CERT_ARN=$IAM_SSL_CERT
elif [[ "$r" == "acm" ]]; then
    NEW_SSL_CERT_ARN="" # null it here, we will find that for each region independently
else
    echo "Wrong input. Enter \"iam\" or \"acm\"."
    exit 1
fi

# run
rm -f $LOG_FILE # cleanup
for REGION in us-west-2 us-west-1 us-east-1 ca-central-1; do  # fill your regions here or supply via list var
    echo "AWS REGION: $REGION ########################" >> $LOG_FILE;
    if [[ "$r" == "acm" ]]; then
        # get ACM Cert in this region
        NEW_SSL_CERT_ARNs=`aws --region $REGION acm list-certificates --query "CertificateSummaryList[?(DomainName == \`$SSL_CERT_DOMAIN_NAME\`)].CertificateArn"`
        for NEW_SSL_CERT_ARN in $NEW_SSL_CERT_ARNs; do
            if [[ `aws --region $REGION acm describe-certificate --certificate-arn $NEW_SSL_CERT_ARN --query 'Certificate.NotAfter'` == $NEW_SSL_CERT_EXP_DATE ]]; then
                # find all Application ALBs
                for alb in `aws --region $REGION elbv2 describe-load-balancers --query 'LoadBalancers[?(Type == \`application\`)].LoadBalancerArn'`; do
                    # loop if there are more than 1 such listeners
                    for l_arn in `aws --region $REGION elbv2 describe-listeners --load-balancer-arn $alb --query 'Listeners[?Protocol==\`HTTPS\`].{ListenerArn:ListenerArn}'`; do 
                        echo "ACM SSL Cert \"$NEW_SSL_CERT_ARN\" will be set for ALB Listener: $l_arn" >> $LOG_FILE
                        aws --region $REGION elbv2 modify-listener --listener-arn $l_arn --certificates CertificateArn=$NEW_SSL_CERT_ARN >> $LOG_FILE 2>&1
                    done
                done
            else
                echo "ACM cert expiration date does not match requirement!"
            fi
        done
    elif [[ "$r" == "iam" ]]; then
        # find all Application ALBs
        for alb in `aws --region $REGION elbv2 describe-load-balancers --query 'LoadBalancers[?(Type == \`application\`)].LoadBalancerArn'`; do
            # loop if there are more than 1 such listeners
            for l_arn in `aws --region $REGION elbv2 describe-listeners --load-balancer-arn $alb --query 'Listeners[?Protocol==\`HTTPS\`].{ListenerArn:ListenerArn}'`; do 
                echo "IAM SSL Cert \"$NEW_SSL_CERT_ARN\" will be set for ALB Listener: $l_arn" >> $LOG_FILE
                aws --region $REGION elbv2 modify-listener --listener-arn $l_arn --certificates CertificateArn=$NEW_SSL_CERT_ARN >> $LOG_FILE 2>&1
            done
        done
    fi
done
