#!/bin/bash

# Describe external ELBs with SSL Cert in Listener and HTTPS protocol only
aws --region us-west-1 elb describe-load-balancers --query "LoadBalancerDescriptions[?(Scheme=='internet-facing' && ListenerDescriptions[?Listener.SSLCertificateId != null] && ListenerDescriptions[?Listener.Protocol == 'HTTPS'])].{LoadBalancerName:LoadBalancerName, ListenerDescriptions:ListenerDescriptions[]}"

# Find all ELBs with Scheme 'internet-facing' with HTTPS Listeners and with SSL certificate installed on them
echo  > elb_443.txt
for REGION in us-west-2 us-west-1 us-east-1 ca-central-1; do 
    echo "AWS REGION: $REGION ########################" >> elb_443.txt;
    aws --region $REGION elb describe-load-balancers --query "LoadBalancerDescriptions[?(Scheme=='internet-facing' && ListenerDescriptions[?Listener.SSLCertificateId != null] && ListenerDescriptions[?Listener.Protocol == 'HTTPS'])].{LoadBalancerName:LoadBalancerName}" >> elb_443.txt
done

# Find all ALBs(Application Load Balancers) with Scheme 'internet-facing' with HTTPS Listeners and with SSL certificate installed on them
echo  > alb_443.txt
for REGION in us-west-2 us-west-1 us-east-1 ca-central-1; do 
    echo "AWS REGION: $REGION ########################" >> alb_443.txt;
    echo "CertificateARN | LoadBalancerListenerARN | LoadBalancerARN" >> alb_443.txt;
    for alb in `aws --region $REGION elbv2 describe-load-balancers --query 'LoadBalancers[?(Type == \`application\`)].LoadBalancerArn'`; do
        aws --region $REGION elbv2 describe-listeners --load-balancer-arn $alb --query 'Listeners[?Protocol==`HTTPS`].{ListenerArn:ListenerArn,LoadBalancerArn:LoadBalancerArn, CertificateArn:Certificates[0].CertificateArn}' >> alb_443.txt;
    done
done

# Check if you have any External ELBs with IAM|ACM SSL Certificate in them 
## Useful if you migrate from IAM SSL to ACM SSL or otherwise. Or just to verify that everything is set correctly
### iam
for REGION in us-east-1 us-west-1 eu-west-1 ap-southeast-1; do 
    aws --region $REGION --output text elb describe-load-balancers --query "LoadBalancerDescriptions[?(Scheme=='internet-facing' && ListenerDescriptions[?Listener.SSLCertificateId != null]|[?starts_with(Listener.SSLCertificateId, 'arn:aws:iam')])].{ListenerSSLCert:ListenerDescriptions[].Listener.SSLCertificateId,LoadBalancerName:LoadBalancerName}"; 
done
### acm
for REGION in us-east-1 us-west-1 eu-west-1 ap-southeast-1; do 
    aws --region $REGION --output text elb describe-load-balancers --query "LoadBalancerDescriptions[?(Scheme=='internet-facing' && ListenerDescriptions[?Listener.SSLCertificateId != null]|[?starts_with(Listener.SSLCertificateId, 'arn:aws:acm')])].{ListenerSSLCert:ListenerDescriptions[].Listener.SSLCertificateId,LoadBalancerName:LoadBalancerName}"; 
done

