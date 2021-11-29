data "aws_subnet_ids" "subnets" {
  vpc_id = var.vpc_id
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "ssh_key"
  public_key = var.ssh_key
}

data "aws_db_instance" "database" {
  db_instance_identifier = var.rds_identifier
}

data "aws_db_instance" "replica" {
  db_instance_identifier = "replica"
}

data "template_file" "config_data" {
  template = <<-EOF
		#! /bin/bash
        cd home/ubuntu
        mkdir server
        cd server
        echo "{\"host\":\"${data.aws_db_instance.database.endpoint}\",\"username\":\"${var.database_username}\",\"password\":\"${var.database_password}\",\"database\":\"${var.rds_identifier}\",\"port\":3306,\"s3\":\"${var.s3_bucket}\", \"replica\":\"${data.aws_db_instance.replica.endpoint}\"}" > config.json
        cd ..
        sudo chmod -R 777 server
    EOF
}

// resource "aws_instance" "webapp" {
//   ami           = var.ami_id
//   instance_type = "t2.micro"
//   iam_instance_profile = "${aws_iam_instance_profile.s3_profile.name}"
//   disable_api_termination = false
//   key_name = aws_key_pair.ssh_key.key_name
//   vpc_security_group_ids = [var.security_group_id]
//   subnet_id = element(tolist(data.aws_subnet_ids.subnets.ids),0)
//   user_data = data.template_file.config_data.rendered
//   root_block_device{
//     delete_on_termination = true
//     volume_size = 20
//     volume_type = "gp2"
//   }

//   tags = {
//     Name = "Webapp"
//   }
// }

resource "aws_launch_configuration" "as_conf" {
  name                   = "asg_launch_config"
  image_id               = var.ami_id
  instance_type          = "t2.micro"
  security_groups        = [var.security_group_id]
  key_name               = aws_key_pair.ssh_key.key_name
  iam_instance_profile        =  "${aws_iam_instance_profile.s3_profile.name}"
  associate_public_ip_address = true
  user_data                   = data.template_file.config_data.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    delete_on_termination = true
  }
  // depends_on = [aws_s3_bucket.bucket, aws_db_instance.rds_ins]
}

resource "aws_lb_listener" "webapp-Listener" {
  load_balancer_arn = "${aws_lb.application-Load-Balancer.arn}"
  port              = "80"
  protocol          = "HTTP"
  // certificate_arn   = "${data.aws_acm_certificate.aws_ssl_certificate.arn}"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.albTargetGroup.arn}"
  }
}


resource "aws_lb_target_group" "albTargetGroup" {
  name     = "albTargetGroup"
  port     = "5000"
  protocol = "HTTP"
  vpc_id   = var.vpc_id
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



resource "aws_autoscaling_group" "autoscaling" {
  name                 = "autoscaling-group"
  launch_configuration = "${aws_launch_configuration.as_conf.name}"
  min_size             = 3
  max_size             = 5
  default_cooldown     = 60
  desired_capacity     = 3
  vpc_zone_identifier = [element(tolist(data.aws_subnet_ids.subnets.ids),0), element(tolist(data.aws_subnet_ids.subnets.ids),1), element(tolist(data.aws_subnet_ids.subnets.ids),2)]
  target_group_arns = ["${aws_lb_target_group.albTargetGroup.arn}"]
  tag {
    key                 = "Name"
    value               = "Webapp"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "lb_security_group" {
  name        = "lb_security_group"
  description = "Load Balancer Security Group"
  vpc_id      =  var.vpc_id

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

resource "aws_lb" "application-Load-Balancer" {
  name               = "application-Load-Balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.lb_security_group.id}"]
  subnets            = data.aws_subnet_ids.subnets.ids
  ip_address_type    = "ipv4"
  tags = {
    Environment = "${var.aws_profile}"
    Name        = "applicationLoadBalancer"
  }
}

resource "aws_autoscaling_policy" "awsAutoScalingPolicyDown" {
  autoscaling_group_name = "${aws_autoscaling_group.autoscaling.name}"
  name = "awsAutoScalingPolicyDown"
  adjustment_type = "ChangeInCapacity"
  cooldown = 60
  scaling_adjustment = -1
}


resource "aws_autoscaling_policy" "awsAutoScalingPolicyUp" {
  autoscaling_group_name = "${aws_autoscaling_group.autoscaling.name}"
  name = "awsAutoScalingPolicyUp"
  adjustment_type = "ChangeInCapacity"
  cooldown = 60
  scaling_adjustment = 1
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmHigh" {
  alarm_name = "CPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 2
  threshold = 5
  metric_name = "CPUUtilization"
  statistic = "Average"
  namespace = "AWS/EC2"
  dimensions = {
    AutoScalingGroupName ="${aws_autoscaling_group.autoscaling.name}"
  }

  alarm_actions = [aws_autoscaling_policy.awsAutoScalingPolicyUp.arn]
  alarm_description = "Scale-up if CPU > 90%"
  period = 60
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmLow" {
  alarm_name = "CPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = 2
  threshold = 3
  metric_name = "CPUUtilization"
  statistic = "Average"
  namespace = "AWS/EC2"
  dimensions = {
    AutoScalingGroupName ="${aws_autoscaling_group.autoscaling.name}"
  }
  alarm_actions = [aws_autoscaling_policy.awsAutoScalingPolicyDown.arn]
  alarm_description = "Scale-down if CPU < 3%"
  period = 60
}


resource "aws_iam_role" "ec2_s3_access_role" {
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

resource "aws_iam_policy" "policy" {
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
               "arn:aws:s3:::${var.s3_bucket}",
                "arn:aws:s3:::${var.s3_bucket}/*",
                "arn:aws:s3:::${var.code_deploy_bucket}",
                "arn:aws:s3:::${var.code_deploy_bucket}/*"
                            ]
        }
    ]
    }
    EOF

}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_instance_profile" "s3_profile" {                             
    name  = "s3_profile"                         
    role = aws_iam_role.ec2_s3_access_role.name
}

resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.ec2_s3_access_role.name
}
