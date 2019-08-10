#!/bin/bash

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
