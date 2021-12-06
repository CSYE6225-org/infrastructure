resource "aws_s3_bucket" "s3" {
  bucket = "${var.name}.${var.environment}.${var.domain}"
  acl    = "private"
  force_destroy = true

    lifecycle_rule {
        id      = "long-term"
        enabled = true

        transition {
            days          = 30
            storage_class = "STANDARD_IA"
        }
    }

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }

  // tags = {
  //   Name        = "Profile Picture bucket"
  // }
}

resource "aws_iam_role" "CodeDeployLambdaServiceRole" {
name           = "iam_for_lambda_with_sns"
path           = "/"
assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["lambda.amazonaws.com","codedeploy.us-east-1.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
tags = {
Name = "CodeDeployLambdaServiceRole"
}
}

resource "aws_dynamodb_table" "mydbtable" {
    provider = aws
    name = "csye6225-dynamo"
    hash_key = "id"
    read_capacity = 1
    write_capacity = 1

    attribute {
        name = "id"
        type = "S"
    }

    ttl {
        attribute_name = "TimeToExist"
        enabled        = true
    }

}

resource "aws_s3_bucket_object" "object" {
  bucket = "prod.codedeploy.maneesh.me"
  key    = "lambda_function.zip"
  source = "/Users/maneeshsakthivel/Desktop/Cloud/server.zip"
}

#Lambda Function
resource "aws_lambda_function" "lambdaFunction" {
  s3_bucket = "prod.codedeploy.maneesh.me"
  s3_key    = "lambda_function.zip"
  /* filename         = "lambda_function.zip" */
  function_name    = "lambda_function_name"
  role             = "${aws_iam_role.CodeDeployLambdaServiceRole.arn}"
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  /* source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}" */
  environment {
    variables = {
      timeToLive = "5"
    }
  }
   depends_on = [aws_s3_bucket_object.object]
}



// resource "aws_lambda_function" "lambdaFunction" {
// filename        = "${data.archive_file.dummy.output_path}"
// function_name   = "csye6225"
// role            = "${aws_iam_role.CodeDeployLambdaServiceRole.arn}"
// handler         = "index.handler"
// runtime         = "nodejs12.x"
// memory_size     = 256
// timeout         = 180
// reserved_concurrent_executions  = 5
// environment  {
// variables = {
// DOMAIN_NAME = "prod.maneesh.me"
// table  = aws_dynamodb_table.mydbtable.name
// }
// }
// tags = {
// Name = "Lambda Email"
// }
// }

// data "archive_file" "dummy" {
//   type = "zip"
//   output_path = "/Users/maneeshsakthivel/Desktop/Cloud/server.zip"

//   source {
//     content = "hello"
//     filename = "dummy.txt"

//   }
// }

resource "aws_sns_topic" "EmailNotificationRecipeEndpoint" {
name          = "EmailNotificationRecipeEndpoint"
}

resource "aws_sns_topic_subscription" "topicId" {
topic_arn       = "${aws_sns_topic.EmailNotificationRecipeEndpoint.arn}"
protocol        = "lambda"
endpoint        = "${aws_lambda_function.lambdaFunction.arn}"
depends_on      = [aws_lambda_function.lambdaFunction]
}

resource "aws_lambda_permission" "lambda_permission" {
statement_id  = "AllowExecutionFromSNS"
action        = "lambda:InvokeFunction"
principal     = "sns.amazonaws.com"
source_arn    = "${aws_sns_topic.EmailNotificationRecipeEndpoint.arn}"
function_name = "${aws_lambda_function.lambdaFunction.function_name}"
depends_on    = [aws_lambda_function.lambdaFunction]

}

resource "aws_iam_policy" "lambda_policy" {
name        = "lambda"
depends_on = [aws_sns_topic.EmailNotificationRecipeEndpoint]
policy =  <<EOF
{
          "Version" : "2012-10-17",
          "Statement": [
            {
              "Sid": "LambdaDynamoDBAccess",
              "Effect": "Allow",
              "Action": ["dynamodb:GetItem",
              "dynamodb:PutItem",
              "dynamodb:UpdateItem"],
              "Resource": "arn:aws:dynamodb:us-east-1:***************:table/csye6225-dynamo"
            },
            {
              "Sid": "LambdaSESAccess",
              "Effect": "Allow",
              "Action": ["ses:VerifyEmailAddress",
              "ses:SendEmail",
              "ses:SendRawEmail"],
              "Resource": "arn:aws:ses:us-east-1:***************:identity/*"
            },
            {
              "Sid": "LambdaS3Access",
              "Effect": "Allow",
              "Action": ["s3:GetObject","s3:PutObject"],
              "Resource": "arn:aws:s3:::lambda.codedeploy.bucket/*"
            },
            {
              "Sid": "LambdaSNSAccess",
              "Effect": "Allow",
              "Action": ["sns:ConfirmSubscription"],
              "Resource": "${aws_sns_topic.EmailNotificationRecipeEndpoint.arn}"
            }
          ]
        }
EOF
}

resource "aws_iam_policy" "topic_policy" {
name        = "Topic"
description = ""
depends_on  = [aws_sns_topic.EmailNotificationRecipeEndpoint]
policy      = <<EOF
{
          "Version" : "2012-10-17",
          "Statement": [
            {
              "Sid": "AllowEC2ToPublishToSNSTopic",
              "Effect": "Allow",
              "Action": ["sns:Publish",
              "sns:CreateTopic"],
              "Resource": "${aws_sns_topic.EmailNotificationRecipeEndpoint.arn}"
            }
          ]
        }
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach_predefinedrole" {
role       = "${aws_iam_role.CodeDeployLambdaServiceRole.name}"
depends_on = [aws_iam_role.CodeDeployLambdaServiceRole]
policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach_role" {
role       = "${aws_iam_role.CodeDeployLambdaServiceRole.name}"
depends_on = [aws_iam_role.CodeDeployLambdaServiceRole]
policy_arn = "${aws_iam_policy.lambda_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "topic_policy_attach_role" {
role       = "${aws_iam_role.CodeDeployLambdaServiceRole.name}"
depends_on = [aws_iam_role.CodeDeployLambdaServiceRole]
policy_arn = "${aws_iam_policy.topic_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "dynamoDB_policy_attach_role" {
role       = "${aws_iam_role.CodeDeployLambdaServiceRole.name}"
depends_on = [aws_iam_role.CodeDeployLambdaServiceRole]
policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "ses_policy_attach_role" {
role       = "${aws_iam_role.CodeDeployLambdaServiceRole.name}"
depends_on = [aws_iam_role.CodeDeployLambdaServiceRole]
policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}