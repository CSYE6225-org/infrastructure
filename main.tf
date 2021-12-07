resource "aws_vpc" "vpc_name" {
  cidr_block                       = var.cidr_block
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_classiclink_dns_support   = var.enable_classiclink_dns_support
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "subnet_aws" {

  depends_on = [aws_vpc.vpc_name]

  for_each = var.vpc_subnet_map

  cidr_block              = each.value
  vpc_id                  = aws_vpc.vpc_name.id
  availability_zone       = each.key
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.vpc_name}-subnet-${each.key}"
  }
}

resource "aws_security_group" "application_security" {
  name        = "application"
  description = "security group for the webapp"
  vpc_id      = aws_vpc.vpc_name.id

  ingress = [
    {
      description = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    },
    {
      description = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    },
    {
      description = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    },
    {
      description = "DJANGO"
      from_port        = 5000
      to_port          = 5000
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    }
  ]

  egress = [
    {
      description = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    },
    {
      description = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    },
    {
      description = "POSTGRES"
      from_port        = 5432
      to_port          = 5432
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    },
  ]
  tags = {
    Name = "application"
  }
}

resource "aws_security_group" "database_security" {
  name        = "database"
  description = "security group for the database"
  vpc_id      = aws_vpc.vpc_name.id

  ingress = [
    {
      description = "POSTGRES"
      from_port        = 5432
      to_port          = 5432
      protocol         = "tcp"
      cidr_blocks      = [aws_vpc.vpc_name.cidr_block]
      security_groups = [aws_security_group.application_security.name]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    }
  ]
  tags = {
    Name = "database"
  }
}

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.vpc_name.id

  tags = {
    Name = "${var.vpc_name}-ig-main"
  }
}

resource "aws_route_table" "route_table_id" {
  vpc_id = aws_vpc.vpc_name.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }

}

//Attach route table to all the subnets
resource "aws_route_table_association" "link_subnets" {
  for_each = aws_subnet.subnet_aws
  subnet_id = each.value.id
  route_table_id = aws_route_table.route_table_id.id
}

// Start S3
resource "aws_s3_bucket" "image_bucket" {
  bucket = "${var.vpc_name}.${var.aws_profile}.${var.s3_domain}"
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
}

resource "aws_iam_role" "deploy_lambda_role" {
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

resource "aws_dynamodb_table" "dynamo_db" {
    provider = aws
    name = "dynamodb"
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

resource "aws_s3_bucket_object" "dummy_zip" {
  bucket = "prod.codedeploy.maneesh.me"
  key    = "lambda_function.zip"
  source = "/Users/maneeshsakthivel/Desktop/Cloud/server.zip"
}

#Lambda Function

resource "aws_lambda_function" "send_email_function" {
  s3_bucket = "prod.codedeploy.maneesh.me"
  s3_key    = "lambda_function.zip"
  /* filename         = "lambda_function.zip" */
  function_name    = "lambda_function_name"
  role             = "${aws_iam_role.deploy_lambda_role.arn}"
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  /* source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}" */
  environment {
    variables = {
      timeToLive = "5"
    }
  }
   depends_on = [aws_s3_bucket_object.dummy_zip]
}

// data "archive_file" "dummy" {
//   type = "zip"
//   output_path = "/Users/maneeshsakthivel/Desktop/Cloud/server.zip"

//   source {
//     content = "hello"
//     filename = "dummy.txt"

//   }
// }

resource "aws_sns_topic" "sns_email_notification" {
name          = "EmailNotificationRecipeEndpoint"
}

resource "aws_sns_topic_subscription" "topic_subscription" {
topic_arn       = "${aws_sns_topic.sns_email_notification.arn}"
protocol        = "lambda"
endpoint        = "${aws_lambda_function.send_email_function.arn}"
depends_on      = [aws_lambda_function.send_email_function]
}

resource "aws_lambda_permission" "lambda_permission" {
statement_id  = "AllowExecutionFromSNS"
action        = "lambda:InvokeFunction"
principal     = "sns.amazonaws.com"
source_arn    = "${aws_sns_topic.sns_email_notification.arn}"
function_name = "${aws_lambda_function.send_email_function.function_name}"
depends_on    = [aws_lambda_function.send_email_function]

}


resource "aws_iam_policy" "lamda_ses_sns_policy" {
name        = "lambda"
depends_on = [aws_sns_topic.sns_email_notification]
policy =  <<EOF
{
          "Version" : "2012-10-17",
          "Statement": [
            {
              "Sid": "LambdaSESAccess",
              "Effect": "Allow",
              "Action": ["ses:VerifyEmailAddress",
              "ses:SendEmail",
              "ses:SendRawEmail"],
              "Resource": "arn:aws:ses:us-east-1:***************:identity/*"
            },
            {
              "Sid": "LambdaSNSAccess",
              "Effect": "Allow",
              "Action": ["sns:ConfirmSubscription"],
              "Resource": "${aws_sns_topic.sns_email_notification.arn}"
            }
          ]
        }
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_basic_role" {
role       = "${aws_iam_role.deploy_lambda_role.name}"
depends_on = [aws_iam_role.deploy_lambda_role]
policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_ses_sns_attachment" {
role       = "${aws_iam_role.deploy_lambda_role.name}"
depends_on = [aws_iam_role.deploy_lambda_role]
policy_arn = "${aws_iam_policy.lamda_ses_sns_policy.arn}"
}


resource "aws_iam_role_policy_attachment" "ses_policy_attachment" {
role       = "${aws_iam_role.deploy_lambda_role.name}"
depends_on = [aws_iam_role.deploy_lambda_role]
policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

//RDS 

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "rdssubnetgp"
  subnet_ids = data.aws_subnet_ids.subnets.ids
}

resource "aws_db_parameter_group" "postgres_params" {
  name        = "postgres-parameters"
  family      = "postgres12"
  description = "Postgres parameter group"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "database" {
  identifier             = var.rds_identifier
  instance_class         = "db.t3.micro"
  skip_final_snapshot = true
  storage_type              = "gp2"
  allocated_storage = 20
  max_allocated_storage = 0
  multi_az = false
  name                      = "csye6225"
  engine                 = "postgres"
  engine_version         = "12.8"
  availability_zone = "us-east-1a"
  username               = var.rds_username
  password               = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database_security.id]
  parameter_group_name   = aws_db_parameter_group.postgres_params.name
  publicly_accessible    = false
  backup_retention_period = 1
}

resource "aws_db_instance" "read_replica" {
  identifier             = "replica"
  replicate_source_db = aws_db_instance.database.identifier
  instance_class         = "db.t3.micro"
  name                   = "csye6225-replica"
  engine                 = "postgres"
  engine_version         = "12.8"
  publicly_accessible    = false
  availability_zone = "us-east-1b"
  skip_final_snapshot = true
}

data "aws_subnet_ids" "subnets" {
  depends_on = [aws_vpc.vpc_name, aws_subnet.subnet_aws]
  vpc_id = aws_vpc.vpc_name.id
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "ssh_key"
  public_key = var.ec2_ssh_key
}


data "template_file" "user_data" {
  template = <<-EOF
		#! /bin/bash
        cd home/ubuntu
        mkdir server
        cd server
        echo "{\"host\":\"${aws_db_instance.database.endpoint}\",\"username\":\"${var.rds_username}\",\"password\":\"${var.rds_password}\",\"database\":\"${var.rds_identifier}\",\"port\":3306,\"s3\":\"${aws_s3_bucket.image_bucket.bucket}\", \"replica\":\"${aws_db_instance.read_replica.endpoint}\"}" > config.json
        cd ..
        sudo chmod -R 777 server
    EOF
}

resource "aws_launch_configuration" "launch_conf" {
  name                   = "asg_launch_config"
  image_id               = var.ec2_ami_id
  instance_type          = "t2.micro"
  security_groups        = [aws_security_group.application_security.id]
  key_name               = aws_key_pair.ssh_key.key_name
  iam_instance_profile        =  "${aws_iam_instance_profile.ec2_policy.name}"
  associate_public_ip_address = true
  user_data                   = data.template_file.user_data.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    delete_on_termination = true
  }
}


resource "aws_lb_listener" "http_listner" {
  load_balancer_arn = "${aws_lb.load_balancer.arn}"
  port              = "80"
  protocol          = "HTTP"
  // certificate_arn   = "${data.aws_acm_certificate.aws_ssl_certificate.arn}"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.load_balancer_target.arn}"
  }
}


resource "aws_lb_target_group" "load_balancer_target" {
  name     = "albTargetGroup"
  port     = "5000"
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_name.id
  tags = {
    name = "albTargetGroup"
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    path                = "/healthstatus"
    port                = "5000"
    matcher             = "200"
  }
}


resource "aws_autoscaling_group" "auto_scale" {
  name                 = "autoscaling-group"
  launch_configuration = "${aws_launch_configuration.launch_conf.name}"
  min_size             = 3
  max_size             = 5
  default_cooldown     = 60
  desired_capacity     = 3
  vpc_zone_identifier = [element(tolist(data.aws_subnet_ids.subnets.ids),0), element(tolist(data.aws_subnet_ids.subnets.ids),1), element(tolist(data.aws_subnet_ids.subnets.ids),2)]
  target_group_arns = ["${aws_lb_target_group.load_balancer_target.arn}"]
  tag {
    key                 = "Name"
    value               = "Webapp"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "load_balance_security_group" {
  name        = "lb_security_group"
  description = "Load Balancer Security Group"
  vpc_id      =  aws_vpc.vpc_name.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress{
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress{
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
   ingress{
    description = "Django"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
    }
    ingress{
    description = "Postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

  
  tags = {
    Name = "application"
  }
}


resource "aws_lb" "load_balancer" {
  name               = "application-Load-Balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.load_balance_security_group.id}"]
  subnets            = data.aws_subnet_ids.subnets.ids
  ip_address_type    = "ipv4"
  tags = {
    Environment = "${var.aws_profile}"
    Name        = "applicationLoadBalancer"
  }
}

resource "aws_autoscaling_policy" "auto_scalling_down_policy" {
  autoscaling_group_name = "${aws_autoscaling_group.auto_scale.name}"
  name = "awsAutoScalingPolicyDown"
  adjustment_type = "ChangeInCapacity"
  cooldown = 60
  scaling_adjustment = -1
}

resource "aws_autoscaling_policy" "auto_scalling_up_policy" {
  autoscaling_group_name = "${aws_autoscaling_group.auto_scale.name}"
  name = "awsAutoScalingPolicyUp"
  adjustment_type = "ChangeInCapacity"
  cooldown = 60
  scaling_adjustment = 1
}

resource "aws_cloudwatch_metric_alarm" "alaram_high" {
  alarm_name = "CPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 2
  threshold = 5
  metric_name = "CPUUtilization"
  statistic = "Average"
  namespace = "AWS/EC2"
  dimensions = {
    AutoScalingGroupName ="${aws_autoscaling_group.auto_scale.name}"
  }

  alarm_actions = [aws_autoscaling_policy.auto_scalling_up_policy.arn]
  alarm_description = "Scale-up if CPU > 90%"
  period = 60
}

resource "aws_cloudwatch_metric_alarm" "alaram_low" {
  alarm_name = "CPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = 2
  threshold = 3
  metric_name = "CPUUtilization"
  statistic = "Average"
  namespace = "AWS/EC2"
  dimensions = {
    AutoScalingGroupName ="${aws_autoscaling_group.auto_scale.name}"
  }
  alarm_actions = [aws_autoscaling_policy.auto_scalling_up_policy.arn]
  alarm_description = "Scale-down if CPU < 3%"
  period = 60
}

resource "aws_iam_role" "ec2_role" {
  name               = "EC2-CSYE6225"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "s3_policy" {
    name = "WebAppS3"
    description = "ec2 will be able to talk to s3 buckets"
    policy = <<-EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "sts:AssumeRole",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Effect": "Allow",
            "Resource": [
               "arn:aws:s3:::${aws_s3_bucket.image_bucket.bucket}",
                "arn:aws:s3:::${aws_s3_bucket.image_bucket.bucket}/*",
                "arn:aws:s3:::${var.code_deploy_bucket}",
                "arn:aws:s3:::${var.code_deploy_bucket}/*"
                            ]
        }
    ]
    }
    EOF

}

resource "aws_iam_policy" "ec2_dynamo_policy"{
  name = "Ec2-Dynamo"
  description = "ec2 Permisson for DynamoDb"
  policy = <<-EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [      
              "dynamodb:List*",
              "dynamodb:DescribeReservedCapacity*",
              "dynamodb:DescribeLimits",
              "dynamodb:DescribeTimeToLive"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGet*",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTable",
                "dynamodb:Get*",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWrite*",
                "dynamodb:CreateTable",
                "dynamodb:Delete*",
                "dynamodb:Update*",
                "dynamodb:PutItem",
                "dynamodb:GetItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/csye6225-dynamo"
        }
    ]
    }
    EOF
  }

resource "aws_iam_role_policy_attachment" "dynamo_ec2_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_dynamo_policy.arn
}

resource "aws_iam_policy" "sns_policy" {
name        = "SNS"
description = ""
policy      = <<EOF
{
          "Version" : "2012-10-17",
          "Statement": [
            {
              "Sid": "AllowEC2ToPublishToSNSTopic",
              "Effect": "Allow",
              "Action": ["sns:Publish",
              "sns:CreateTopic"],
              "Resource": "arn:aws:sns:us-east-1:686302940114:EmailNotificationRecipeEndpoint"
            }
          ]
        }
EOF
}

resource "aws_iam_role_policy_attachment" "ec2_sns_attach" {
role       = "${aws_iam_role.ec2_role.name}"
policy_arn = "${aws_iam_policy.sns_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "ec2_s3_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_instance_profile" "ec2_policy" {                             
    name  = "s3_profile"                         
    role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy_attachment" "cloud_watch_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.ec2_role.name
}