# Terraform script for AWS

#Configuring cloud provider for script
provider "aws" {
  region  = "eu-west-1"
}

#creating S3 bucket resource for the spider_indexer, making it public and have versioning enabled
resource "aws_s3_bucket" "spider_s3" {
  bucket = "new-40175607assignment3"
  acl    = "private"

  tags = {
    Name        = "Bucket for source code for spider_indexer"
    Environment = "Dev"
}
  versioning  {
  enabled = true
  }
}


#creating S3 bucket resource for the front-end, making it public and have versioning enabled
#bucket enabled for static web hosting to host the front-end
resource "aws_s3_bucket" "front_end_s3" {
  bucket = "new-qse40175607"
  acl    = "public-read"

  tags = {
    Name        = "Bucket for source code for QSE front-end"
    Environment = "Dev"
}
  versioning  {
  enabled = true
  }

  website  {
      index_document = "index.html"
      error_document = "404.html"
      }
  }

#create CodeCommit repository to act as a repository for the spider_indexer
resource "aws_codecommit_repository" "spider_indexer_repo" {
  repository_name = "new_spider_indexer"
  description     = "Repository for the spider_indexer web crawler"
}

#create CodeCommit repository to act as a repository for the front-end
resource "aws_codecommit_repository" "front_end_repo" {
  repository_name = "new_front_end_repo"
  description     = "Repository for the front end code"
}

resource "aws_iam_role" "ci_role" {
  name = "ci_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
      "Service": ["codebuild.amazonaws.com", "codepipeline.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ci_instance_profile" {
  name = "ci_instance_profile"
  role = "${aws_iam_role.ci_role.name}"
}


resource "aws_iam_role_policy" "ci_policy" {
  name = "ci_policy"
  role = "${aws_iam_role.ci_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "logs:*",
      "Effect": "Allow",
      "Resource":  "*"

    },
    {
      "Action": "codecommit:*",
      "Effect": "Allow",
      "Resource":"*"
    },
    {
    "Action": "codepipeline:*",
    "Effect": "Allow",
    "Resource":"*"

    },
    {
    "Action": "codebuild:*",
    "Effect": "Allow",
    "Resource":"*"
    }
  ]
}
EOF
}

#CodeBuild project resource for spider_indexer
resource "aws_codebuild_project" "spider_indexer_codebuild" {
  name          = "new_spider_indexer_build"
  description   = "codebuild project for spider indexer"
  build_timeout = "5"
  service_role  = "${aws_iam_role.ci_role.arn}"     #Build project assigned to CodeBuild role & policy

  artifacts {
    type = "NO_ARTIFACTS"
  }


  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"              #Environment that is running the build
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
}

  logs_config {                           #Configure Cloudwatch to store the logs from any builds
    cloudwatch_logs {
      group_name = "log-group"
      stream_name = "log-stream"
    }
  }

  source {
    type            = "CODECOMMIT"       #CodeBuild project gets source code from spider indexer CodeCommit repository
    location        = "aws_codecommit_repository.new_spider_indexer"
    git_clone_depth = 1
  }

  tags = {
    Environment = "Dev"
  }
}



#CodeBuild project resource for front-end
resource "aws_codebuild_project" "front_end_codebuild" {
  name          = "new_front_end"
  description   = "codebuild project for front-end"
  build_timeout = "5"
  service_role  = "${aws_iam_role.ci_role.arn}"     #Build project assigned to CodeBuild role & policy

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
}
  logs_config {
    cloudwatch_logs {                             #Configure Cloudwatch to store the logs from any builds
      group_name = "log-group"
      stream_name = "log-stream"
    }
  }

  source {
    type            = "CODECOMMIT"               #CodeBuild project gets source code from front-end CodeCommit repo
    location        = "aws_codecommit_repository.new_front_end_repo"
    git_clone_depth = 1
  }

  tags = {
    Environment = "Dev"
  }

    }

#CodePipeline resource for spider_indexer
resource "aws_codepipeline" "spider_indexer_codepipeline" {
  name     = "new_spider_indexer"
  role_arn = "${aws_iam_role.ci_role.arn}"        #CodePipeline assigned to CodeBuild role & policy

  artifact_store {
    location = "${aws_s3_bucket.spider_s3.bucket}"         #Artifacts stored in S3 bucket
    type     = "S3"

  }

  stage {
    name = "Source"

    action {
      name             = "Source"              #Install Stage that installs any Python dependancies
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"           #Source in pipeline is from the CodeCommit repository
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName  = "new_spider_indexer"
        BranchName = "master"
      }
    }
  }

  stage {
    name = "Build"                              #Build stage that compiles source code and initiates build project

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"          #Build stage uses CodeBuild as the source
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "new_spider_indexer_build"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"            #Deploy stage is the final stage in pipeline that deploys to the S3 bucket
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
                BucketName = "new-40175607assignment3"
                Extract = true
      }
    }
  }
}

#CodePipeline resource for front-end
resource "aws_codepipeline" "front_end_codepipeline" {
  name     = "new_frontend"
  role_arn = "${aws_iam_role.ci_role.arn}"          #CodePipeline assigned to CodeBuild role & policy

  artifact_store {
    location = "${aws_s3_bucket.front_end_s3.bucket}"                  #Artifacts stored in S3 bucket
    type     = "S3"

  }

  stage {
    name = "Source"

    action {
      name             = "Source"                        #Install Stage that installs any dependancies
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"                    #Source in pipeline is from the CodeCommit repository
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName   = "new_front_end_repo"
        BranchName = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"                       #Build stage that compiles source code and initiates build project
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"                  #Build stage uses CodeBuild as the source
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "front_end_codebuild"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"                       #Deploy stage is the final stage in pipeline that deploys to the S3 bucket
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        BucketName = "new-qse40175607"
        Extract = true
      }
    }
  }
}

#create role for lambda function with permissions for lambda service
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
      "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#create instance profile for lambda role and policy
resource "aws_iam_instance_profile" "lambda_instance_profile" {
  name = "lambda_instance_profile"
  role = "${aws_iam_role.lambda_role.name}"
}

#create role policy for lambda function
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = "${aws_iam_role.lambda_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "logs:*",
      "Effect": "Allow",
      "Resource":  "*"

    },
    {
      "Action": "lambda:*",
      "Effect": "Allow",
      "Resource":"*"
    }

  ]
}
EOF
}

#Create lambda function that initialises the name of the zipped deployment package, function name, IAM role, lambda handler and runtime
resource "aws_lambda_function" "spider_indexer_lambda" {
  filename      = "spider_indexer.zip"
  function_name = "lambda_handler"
  role          = "${aws_iam_role.iam_for_lambda}"
  handler       = "spider_indexer.py"

  runtime = "Python 3.7"          #Set runtime env that function runs in
}

#Create API Gateway resource for calling the lambda function
resource "aws_api_gateway_rest_api" "spider_api_gateway" {
  name = "spider_indexer"
}

#Create API Gateway resource for the searching mechanism
resource "aws_api_gateway_rest_api" "search_api_gateway" {
  name = "search_api"
}

#Create API Gateway resource for the ads mechanism
resource "aws_api_gateway_rest_api" "ads_api_gateway" {
  name = "ads_api"
}

#Create SNS topic for the CodePipeline, used to send emails of any alerts or errors from pipeline
resource "aws_sns_topic" "pipeline_sns" {
  name = "pipeline_sns"
}

#Create SNS topic for the spider_indexer DynamoDB table, used to send emails of any alerts or errors from table to any subscribers
resource "aws_sns_topic" "spider_sns" {
  name = "spider_sns"
}

#Create SNS topic for the ads DynamoDB table, used to send emails of any alerts or errors from table to any subscribers
resource "aws_sns_topic" "ads_sns" {
  name = "ads_sns"
}

#Cloudwatch event used for monitoring, if threshold met or error occurs etc Cloudwatch sends info to an SNS Topic
resource "aws_cloudwatch_event_target" "sns" {
  rule      = "${aws_cloudwatch_event_rule.console.name}"
  target_id = "SendToSNS"
  arn       = "${aws_sns_topic.pipeline_sns}"
}

#Create SNS topic policy, this policy dictates what info is sent to the subscribers of the topic
resource "aws_sns_topic_policy" "default" {
  arn    = "${aws_sns_topic.aws_logins.arn}"
  policy = "${data.aws_iam_policy_document.sns_topic_policy.json}"
}

#create spider indexer dynamodDB table
resource "aws_dynamodb_table" "spider_dynamodb" {
  name           = "new_spider_dynamodb"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "Title"    #hash/primary key

  #creating all table attributes/columns
  attribute {
    name = "Title"
    type = "S"
  }
  attribute {
    name = "Heading1"
    type = "S"
  }
  attribute {
    name = "Heading2"
    type = "S"
  }

  attribute {
    name = "URLText"
    type = "S"
  }

}

#create ads dynamodDB table
resource "aws_dynamodb_table" "ads_dynamodb" {
  name           = "new_ads_dynamodb"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "Title"    #hash/primary key

  #creating all table attributes/columns
  attribute {
    name = "Title"
    type = "S"
  }
  attribute {
    name = "Description"
    type = "S"
  }
  attribute {
    name = "Description2"
    type = "S"
  }

  attribute {
    name = "Description3"
    type = "S"
  }

}

#create elasticsearch resouce for main search - similar to CloudSearch service but CloudSearch seems to be unavailable in terraform
resource "aws_elasticsearch_domain" "main_search" {
  domain_name           = "search"
  elasticsearch_version = "1.5"

  cluster_config {
    instance_type = "r4.large.elasticsearch"    #domain instance size
  }

  snapshot_options {                            #create snapshot
    automated_snapshot_start_hour = 23
  }

  tags = {
    Domain = "SearchDomain"
  }
}

#create elasticsearch resouce for ads search - similar to CloudSearch service but CloudSearch seems to be unavailable in terraform
resource "aws_elasticsearch_domain" "ads_search" {
  domain_name           = "ads"
  elasticsearch_version = "1.5"

  cluster_config {
    instance_type = "r4.large.elasticsearch"    #domain instance size
  }

  snapshot_options {                            #create snapshot
    automated_snapshot_start_hour = 23
  }

  tags = {
    Domain = "SearchDomain"
  }
}

#create role for dynamoDB service so only authorised users can access, edit, delete anything int ables
resource "aws_iam_role" "dynamodb_role" {
  name = "dynamoDB_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "dynamodb.amazonaws.com"         #assign role to dynamodb service
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#Create IAM policy for DynamoDB role ensuring only authorised users with the correct permissions can edit, add, delete from dynamodb table
resource "aws_iam_role_policy" "dynamodb_role" {
  role = "${aws_iam_role.dynamodb_role.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [                       #Enable cloudwatch logging
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",                      #Role allows user the required access to add, edit and delete from dynamodb tables
      "Action": [
                  "dynamodb:DeleteItem",
                  "dynamodb:DescribeContributorInsights",
                  "dynamodb:RestoreTableToPointInTime",
                  "dynamodb:PurchaseReservedCapacityOfferings",
                  "dynamodb:ListTagsOfResource",
                  "dynamodb:CreateTableReplica",
                  "dynamodb:UpdateContributorInsights",
                  "dynamodb:UpdateGlobalTable",
                  "dynamodb:CreateBackup",
                  "dynamodb:DeleteTable",
                  "dynamodb:UpdateTableReplicaAutoScaling",
                  "dynamodb:UpdateContinuousBackups",
                  "dynamodb:DescribeReservedCapacityOfferings",
                  "dynamodb:DescribeTable",
                  "dynamodb:GetItem",
                  "dynamodb:DescribeContinuousBackups",
                  "dynamodb:CreateGlobalTable",
                  "dynamodb:DescribeLimits",
                  "dynamodb:BatchGetItem",
                  "dynamodb:UpdateTimeToLive",
                  "dynamodb:BatchWriteItem",
                  "dynamodb:ConditionCheckItem",
                  "dynamodb:PutItem",
                  "dynamodb:Scan",
                  "dynamodb:Query",
                  "dynamodb:DescribeStream",
                  "dynamodb:UpdateItem",
                  "dynamodb:DeleteTableReplica",
                  "dynamodb:DescribeTimeToLive",
                  "dynamodb:ListStreams",
                  "dynamodb:CreateTable",
                  "dynamodb:UpdateGlobalTableSettings",
                  "dynamodb:DescribeGlobalTableSettings",
                  "dynamodb:GetShardIterator",
                  "dynamodb:DescribeGlobalTable",
                  "dynamodb:DescribeReservedCapacity",
                  "dynamodb:RestoreTableFromBackup",
                  "dynamodb:DescribeBackup",
                  "dynamodb:DeleteBackup",
                  "dynamodb:UpdateTable",
                  "dynamodb:GetRecords",
                  "dynamodb:DescribeTableReplicaAutoScaling"
      ],
      "Resource": "*"             #Role applies to all existing dynamodb tables - spider_indexer & ads

    },

    {
      "Effect": "Allow",              #Role also requires GET access from Lambda, spider_indexer lambda function is used to put entries into DB so DB will need
      "Action": [                                                                 #limited access to some lambda actions
                "lambda:GetLayerVersion",
                "lambda:GetEventSourceMapping",
                "lambda:ListTags",
                "lambda:GetFunction",
                "lambda:GetAccountSettings",
                "lambda:GetFunctionConfiguration",
                "lambda:GetAlias",
                "lambda:GetLayerVersionPolicy",
                "lambda:GetPolicy"
            ],
      "Resource": "*""

      }
    ]
}
POLICY
}

#https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/metrics-dimensions.html
#cloudwatch alarms for dynamoDB - alarm if total reads of the table exceeds a certain value
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_alarm" {
  alarm_name                = "DynamoDB read usage"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "ConsumedReadCapacityUnits"
  namespace                 = "AWS/DynamoDB"
  period                    = "3600"
  statistic                 = "Sum"
  threshold                 = "80"
  alarm_description         = "This metric monitors the number of reads of the DynamoDB tables"
  insufficient_data_actions = []
}

#https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/metrics-dimensions.html
#cloudwatch alarms for dynamoDB - alarm if total writes of the table exceeds a certain value
resource "aws_cloudwatch_metric_alarm" "dynamodb_write_alarm" {
  alarm_name                = "DynamoDB write usage"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "ConsumedWriteCapacityUnits"
  namespace                 = "AWS/DynamoDB"
  period                    = "3600"      #metric checked in a period of every hour
  statistic                 = "Sum"
  threshold                 = "80"
  alarm_description         = "This metric monitors the number of write of the DynamoDB tables"
  insufficient_data_actions = []
}
