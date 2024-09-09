# 신규 인프라 생성 시 사용하는 AWS Chatbot using Terraform

### Get Started
0. cd ./${ENVIRONMENT}
1. terraform init
2. AWS Chatbot connection to Slack
3. Create KMS for region
4. edit the key policy to grant CloudWatch Customer-managed keys(CMK) 
```
{    
  "Sid": "Allow use of the key",  
  "Effect": "Allow",  
  "Principal": {  
    "Service": [
      "events.amazonaws.com",
      "cloudwatch.amazonaws.com"
    ],
  },  
  "Action": [  
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:DescribeKey"
  ],  
  "Resource": "*"  
}
```
5. AWS_PROFILE=${YOUR_PROFILE} terraform plan
6. AWS_PROFILE=${YOUR_PROFILE} terraform apply -auto-approve
