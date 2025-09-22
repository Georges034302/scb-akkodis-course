#!/usr/bin/env bash
# setup_vmimport.sh — minimal, argument-driven (no managed policy, no AMI vars)
# Usage: ./setup_vmimport.sh <SUFFIX>
# Example: ./setup_vmimport.sh 872
set -euo pipefail
IFS=$'\n\t'

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <SUFFIX>"
  exit 1
fi

SUFFIX="$1"
BUCKET="ec2-export-bucket-${SUFFIX}-source"
PREFIX="exports/"
ROLE_NAME="vmimport"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo "Account: ${ACCOUNT_ID}"
echo "Bucket:  ${BUCKET}"
echo "Prefix:  ${PREFIX}"
echo "Role:    ${ROLE_ARN}"

# Ensure bucket exists (must be created ahead of time)
aws s3api head-bucket --bucket "${BUCKET}" >/dev/null 2>&1 || { echo "Bucket '${BUCKET}' not found. Create it first: aws s3 mb s3://${BUCKET}"; exit 1; }

# Trust policy (create or update)
cat > trust-policy.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "vmie.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
JSON

if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  aws iam update-assume-role-policy --role-name "${ROLE_NAME}" --policy-document file://trust-policy.json
else
  aws iam create-role --role-name "${ROLE_NAME}" --assume-role-policy-document file://trust-policy.json >/dev/null
fi

# Inline policy (covers EC2 + S3 required actions)
cat > vmimport-inline-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2PermissionsForExport",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateTags",
        "ec2:CopySnapshot",
        "ec2:ModifySnapshotAttribute"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3BucketLevel",
      "Effect": "Allow",
      "Action": [ "s3:GetBucketLocation", "s3:ListBucket" ],
      "Resource": "arn:aws:s3:::${BUCKET}"
    },
    {
      "Sid": "S3ObjectLevel",
      "Effect": "Allow",
      "Action": [ "s3:GetObject", "s3:GetObjectAcl", "s3:PutObject", "s3:PutObjectAcl" ],
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    }
  ]
}
JSON

aws iam put-role-policy --role-name "${ROLE_NAME}" --policy-name vmimport-inline --policy-document file://vmimport-inline-policy.json

# Bucket policy (apply immediately)
cat > bucket-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowVMImportPutObjects",
      "Effect": "Allow",
      "Principal": { "AWS": "${ROLE_ARN}" },
      "Action": [ "s3:PutObject", "s3:PutObjectAcl" ],
      "Resource": "arn:aws:s3:::${BUCKET}/${PREFIX}*"
    },
    {
      "Sid": "AllowVMImportListAndLocation",
      "Effect": "Allow",
      "Principal": { "AWS": "${ROLE_ARN}" },
      "Action": [ "s3:GetBucketLocation", "s3:ListBucket" ],
      "Resource": "arn:aws:s3:::${BUCKET}"
    }
  ]
}
JSON

aws s3api put-bucket-policy --bucket "${BUCKET}" --policy file://bucket-policy.json

echo "Done. vmimport role and bucket policy configured for ${BUCKET}."
