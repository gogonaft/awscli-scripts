#!/bin/bash

# Find files in S3 bucket by PREFIX and copy them all to temp dir 

TEMP_DIR="s3_find_temp_dir/"

if [ $# -eq 0 ]
  then
    echo "No arguments supplied. Working with manual input..."
    echo "Enter S3 bucket name: (Example: bucket-name )"
    read s3_bucket
    echo "Enter S3 prefix in bucket: (Example: somedir/path-to-file or somedir/prefix-for-multiple-files )"
    read s3_prefix
    echo "Result of search: (Output is S3 locations in a bucket)"
    #arr=$(aws s3api list-objects-v2 --bucket $s3_bucket --prefix $s3_prefix --query Contents[].[Size,Key] | xargs)
    arr=$(aws s3api list-objects-v2 --bucket $s3_bucket --prefix $s3_prefix --query Contents[].[Key] | xargs)
    mkdir s3_find_temp
    for i in $arr; do aws s3 cp s3://$s3_bucket/$i $TEMP_DIR; done
    ls -ltrh $TEMP_DIR
  else
    echo "Working with script arguments..."
    arr=$(aws s3api list-objects-v2 --bucket $1 --prefix $2 --query Contents[].[Key] | xargs)
    mkdir s3_find_temp
    for i in $arr; do aws s3 cp s3://$1/$i $TEMP_DIR; done
    ls -ltrh $TEMP_DIR
fi
