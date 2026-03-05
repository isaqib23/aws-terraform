# Latest Amazon Linux 2 ARM AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.bastion_sg_id]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  # Match prod: install kubectl, helm, terraform, kubens, AWS CLI, session manager
  user_data = <<-EOF
    #!/bin/bash
    # Update and install required packages
    sudo yum update -y
    sudo yum install -y git curl unzip

    # Install kubectl
    curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-12-20/bin/linux/arm64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin

    # Install kubens/kubectx
    sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
    sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
    sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
    echo "source /opt/kubectx/completion/kubectx.bash" >> ~/.bashrc
    echo "source /opt/kubectx/completion/kubens.bash" >> ~/.bashrc

    # Install Helm
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh

    # Install session manager plugin
    sudo dnf install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm

    # Install terraform
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    sudo yum -y install terraform

    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
  EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion"
  }
}
