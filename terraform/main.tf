provider "aws" {
  region = "us-east-1"
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable subnet2_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}
variable image_name {}
variable image_name_ubuntu {}
variable ssh_key_private {}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
    tags = {
    Name: "${var.env_prefix}-subnet-1"
  }
}


resource "aws_subnet" "myapp-subnet-2" { # private subnet for database server
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet2_cidr_block
  availability_zone = var.avail_zone
    tags = {
    Name: "${var.env_prefix}-subnet-private"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name: "${var.env_prefix}-igw"
  }
}

resource "aws_eip" "nat_eip" { # creates elastic ip for nat gateway to access internet
    domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" { # creates a nat gateway and allocates the elastic ip to it
    allocation_id =  aws_eip.nat_eip.id
    subnet_id = aws_subnet.myapp-subnet-1.id

}


resource "aws_route_table" "private-rtb" { # creates a route table for the private subnet and associates with the VPC
  vpc_id = aws_vpc.myapp-vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
      Name : "${var.env_prefix}-private-rtb"
  }

}

resource "aws_route_table_association" "private-rtb-association" {
    subnet_id = aws_subnet.myapp-subnet-2.id
    route_table_id = aws_route_table.private-rtb.id
}

resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name: "${var.env_prefix}-main-rtb"
  }
}


resource "aws_default_security_group" "default-sg" {
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = [var.vpc_cidr_block]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name: "${var.env_prefix}-default-sg"
  }
}



resource "aws_security_group" "private-sg" {
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = [var.vpc_cidr_block]
  }

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "TCP"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name: "${var.env_prefix}-private-sg"
  }
}

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name" 
    values = [var.image_name]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "latest-ubuntu-image" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name" 
    values = [var.image_name_ubuntu]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

# output "aws-ami_id" {
#   value = data.aws_ami.latest-amazon-linux-image.id
# }

# output "aws-ami_id_ubuntu" {
#   value = data.aws_ami.latest-ubuntu-image.id
# }

output "ansible-server" {
  value = aws_instance.ansible-server.public_ip
}

output "web-server" {
  value = aws_instance.web-server.public_ip
}

output "web-server_private" {
  value = aws_instance.web-server.private_ip
}

output "database-server" {
  value = aws_instance.database-server.private_ip
}


resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file(var.public_key_location)
}

resource "aws_instance" "ansible-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.default-sg.id]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  tags = {
    Name: "${var.env_prefix}-ansible-server"
  }

  

}


resource "aws_instance" "web-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.default-sg.id]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  tags = {
    Name: "${var.env_prefix}-web-server"

  }
}


resource "aws_instance" "database-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.myapp-subnet-2.id
  vpc_security_group_ids = [aws_security_group.private-sg.id]
  availability_zone = var.avail_zone

  key_name = aws_key_pair.ssh-key.key_name

  tags = {
    Name: "${var.env_prefix}-database-server"

  }
}


resource "local_file" "ansible_inventory" {
  filename = "../ansible/ansible-config/inventory.ini"

  content = templatefile("inventory.ini.tftpl", {

    ip_one = aws_instance.ansible-server.public_ip
    ip_two = aws_instance.database-server.private_ip
    ip_three = aws_instance.web-server.public_ip
    ip_three_private = aws_instance.web-server.private_ip


  }
  
  )


}


resource "null_resource" "configure_server" {

    triggers = {
        trigger_one = aws_instance.ansible-server.public_ip

    }

    provisioner "local-exec" {
        working_dir = "../ansible"
        command = "ansible-playbook --inventory ../ansible/ansible-config/inventory.ini --private-key ${var.ssh_key_private} ../ansible/ansible-config/provision-ansible-server.yaml"
    }


}





