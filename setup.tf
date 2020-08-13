variable "whitelist" {             
  type = list(string)
}
variable "web_instance_type" {      
    type = string
}
variable "web_desired_capacity" {   
    type = number 
}
variable "web_max_size" {           
    type = number 
}
variable "web_min_size" {
  type = number
}


provider "aws" {

  profile = "default"
  region = "us-west-1"

}
resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_az1" {

  availability_zone = "us-west-1a"
  tags = {
    "Terraform" : "true"
  }

}

resource "aws_default_subnet" "default_az2" {

  availability_zone = "us-west-1c"
  tags = {
    "Terraform" : "true"
  }


}

resource "aws_subnet" "subnet-private-1" {
    vpc_id = "${aws_default_vpc.default.id}"
    cidr_block = "172.31.32.0/24"
    availability_zone = "us-west-1a"
    tags = {
       "Terraform" = "true"
    }
}


resource "aws_subnet" "subnet-private-2" {
    vpc_id = "${aws_default_vpc.default.id}"
    cidr_block = "172.31.33.0/24" 
    availability_zone = "us-west-1a"
    tags = {
       "Terraform" = "true"
    }
}





resource "aws_security_group" "prod_web" {
  name        = "prod_web"
  description = "allow httpd inbound and everything outbound"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.whitelist
  }
  
  ingress {
    from_port    = 443 
    to_port      = 443
    protocol     = "tcp"
    cidr_blocks  = var.whitelist   
  }


  ingress {
    from_port    = 8080  
    to_port      = 8080
    protocol     = "tcp"
    cidr_blocks  = var.whitelist   
  }


  ingress {
    from_port    = 22  
    to_port      = 22
    protocol     = "tcp"
    cidr_blocks  = var.whitelist   
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.whitelist 
  }

  tags = {
    "Terraform"	: "true"
  }

}


data "aws_ami" "sample_tomcat_app_ami" {
  most_recent = true
filter {
    name   = "name"
    values = ["Demo-image*"]
  }
filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
owners = ["325940544892"]
}


resource "aws_elb" "prod_web" {
  name            = "prod-web"
  subnets         = [aws_default_subnet.default_az1.id , aws_default_subnet.default_az2.id]
  security_groups = [aws_security_group.prod_web.id]
  
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  tags = {
    "Terraform" : "true"
  }

  
}

/*
resource "aws_launch_template" "prod_web" {
  name_prefix   = "prod-web"
  image_id      = data.aws_ami.sample_tomcat_app_ami.id
  instance_type = var.web_instance_type
  vpc_security_group_ids = [aws_security_group.prod_web.id]
}
*/


resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  instance_type = "t2.micro"

  image_id      = data.aws_ami.sample_tomcat_app_ami.id

  security_groups = [aws_security_group.prod_web.id]
 # user_data = "sudo /usr/"
  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_autoscaling_group" "prod_web" {
#  availability_zones = ["us-west-1a", "us-west-1c"]
  vpc_zone_identifier = [aws_default_subnet.default_az1.id,aws_default_subnet.default_az2.id]
  desired_capacity   = var.web_desired_capacity
  max_size           = var.web_max_size
  min_size           = var.web_min_size
  launch_configuration = aws_launch_configuration.web.name

   tag {
    key                 = "Terraform"
    value               = "true"
    propagate_at_launch = true
  }

}

 
resource "aws_autoscaling_attachment" "prod_Web" {
  autoscaling_group_name = aws_autoscaling_group.prod_web.id
  elb                    = aws_elb.prod_web.id
}



