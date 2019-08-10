#!/bin/bash

# AWS ELBs - Change All port 443 HTTPS Protocol ELB Listeners SSL Certificate to new one of either IAM or ACM source 
## Useful when you have old IAM SSL Cert installed and want to migrate to ACM. Or you just want to use completely different SSL Certificate.

# envs
LOG_FILE="alb_update.log"
NEW_SSL_CERT_EXP_DATE="1612340000.0" # result of -> aws --region $REGION acm describe-certificate --certificate-arn <ACM_ARN_OF_NEW_SSL_CERT> --query 'Certificate.NotAfter'
#date -d @1612340000.0  --> "Wed Feb  3 08:13:20 UTC 2021"
IAM_SSL_CERT="arn:aws:iam::<aws_root_account_id>:server-certificate/<iam_ssl_cert_name>"

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

# all LISTENERS port 443 ext ELBs in a region
rm -f $LOG_FILE # cleanup on re-run
for REGION in us-west-2 us-west-1 us-east-1 ca-central-1; do 
    rm -f elb_443_$REGION.txt # clean on re-run
    echo "AWS REGION: $REGION ########################" >> $LOG_FILE;
    aws --region $REGION elb describe-load-balancers --query "LoadBalancerDescriptions[?(Scheme=='internet-facing' && ListenerDescriptions[?Listener.SSLCertificateId != null] && ListenerDescriptions[?Listener.Protocol == 'HTTPS'])].{LoadBalancerName:LoadBalancerName}" >> elb_443_$REGION.txt
    
    if [[ "$r" == "acm" ]]; then
        # get ACM Cert in this region
        NEW_SSL_CERT_ARNs=`aws --region $REGION acm list-certificates --query 'CertificateSummaryList[?(DomainName == \`*.genesyscloud.com\`)].CertificateArn'`
        for NEW_SSL_CERT_ARN in $NEW_SSL_CERT_ARNs; do
            if [[ `aws --region $REGION acm describe-certificate --certificate-arn $NEW_SSL_CERT_ARN --query 'Certificate.NotAfter'` == $NEW_SSL_CERT_EXP_DATE ]]; then
                while read elb; do
                    echo "ACM SSL Cert \"$NEW_SSL_CERT_ARN\" will be set for Listener of ELB: $elb"  >> $LOG_FILE
                    aws --region $REGION elb set-load-balancer-listener-ssl-certificate --load-balancer-name $elb  --load-balancer-port 443 --ssl-certificate-id $NEW_SSL_CERT_ARN >> $LOG_FILE 2>&1
                done < elb_443_$REGION.txt
            fi
        done
    elif [[ "$r" == "iam" ]]; then
        while read elb; do
            echo "IAM SSL Cert \"$NEW_SSL_CERT_ARN\" will be set for Listener of ELB: $elb"  >> $LOG_FILE
            aws --region $REGION elb set-load-balancer-listener-ssl-certificate --load-balancer-name $elb  --load-balancer-port 443 --ssl-certificate-id $NEW_SSL_CERT_ARN >> $LOG_FILE 2>&1
        done < elb_443_$REGION.txt
    fi
done
