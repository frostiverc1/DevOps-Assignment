data "aws_ami" "ubuntu_22" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Elastic IP (gives us a stable IP for nip.io DNS + Certbot) ────────────────

resource "aws_eip" "vps" {
  domain = "vpc"
  tags   = { Name = "${var.project}-vps-eip", Project = var.project }
}

# ── Security Group ─────────────────────────────────────────────────────────────

resource "aws_security_group" "vps" {
  name        = "${var.project}-vps-sg"
  description = "VPS: SSH from your IP only, HTTP/HTTPS from anywhere"

  ingress {
    description = "SSH — restricted to your IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-vps-sg", Project = var.project }
}

# ── EC2 Instance ───────────────────────────────────────────────────────────────

resource "aws_instance" "vps" {
  ami                         = data.aws_ami.ubuntu_22.id
  instance_type               = "t3.micro"
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.vps.id]
  associate_public_ip_address = true

  # Pass the Elastic IP to userdata so Certbot gets the nip.io domain
  user_data = templatefile("${path.module}/ec2-userdata.sh", {
    elastic_ip = aws_eip.vps.public_ip
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = { Name = "${var.project}-vps", Project = var.project }
}

# Attach the Elastic IP to the instance
resource "aws_eip_association" "vps" {
  instance_id   = aws_instance.vps.id
  allocation_id = aws_eip.vps.id
}
