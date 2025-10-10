data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "sftp" {
  name        = "${var.name}-sg"
  description = "Allow SFTP/SSH"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-sg" })

  ingress {
    description = "SSH/SFTP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Optional: Elastic IP to keep the public IP fixed
resource "aws_eip" "this" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-eip" })
}

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y openssh-server

    # Create SFTP-only group and user
    groupadd sftpusers || true
    useradd -G sftpusers -s /sbin/nologin -m ${var.sftp_username} || true

    # SFTP chroot structure
    mkdir -p /sftp/${var.sftp_username}/upload/incoming
    chown root:root /sftp
    chmod 755 /sftp
    chown root:root /sftp/${var.sftp_username}
    chmod 755 /sftp/${var.sftp_username}
    chown ${var.sftp_username}:${var.sftp_username} /sftp/${var.sftp_username}/upload
    chown -R ${var.sftp_username}:${var.sftp_username} /sftp/${var.sftp_username}/upload/incoming

    # SSH key auth
    install -d -m 700 /home/${var.sftp_username}/.ssh
    echo "${var.sftp_user_pubkey}" > /home/${var.sftp_username}/.ssh/authorized_keys
    chown -R ${var.sftp_username}:${var.sftp_username} /home/${var.sftp_username}/.ssh
    chmod 600 /home/${var.sftp_username}/.ssh/authorized_keys

    # Configure sshd for sftp-only chroot
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    cat <<'SSHD' >/etc/ssh/sshd_config
    Port 22
    Protocol 2
    PermitRootLogin no
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    UsePAM yes
    Subsystem sftp internal-sftp

    Match Group sftpusers
      ChrootDirectory /sftp/%u
      ForceCommand internal-sftp
      X11Forwarding no
      AllowTcpForwarding no
    SSHD

    systemctl enable sshd
    systemctl restart sshd

    # Seed dummy CSV files (incoming transaction drops)
    cat <<'CSV' >/sftp/${var.sftp_username}/upload/incoming/transactions_2025-10-10.csv
    ID,ClientID,Transaction,Amount,Date,Status
    T0001,C001,D,1200.50,2025-10-09,Completed
    T0002,C001,W,100.00,2025-10-09,Completed
    T0003,C002,D,250.00,2025-10-09,Pending
    T0004,C003,W,75.25,2025-10-08,Failed
    CSV

    cat <<'CSV' >/sftp/${var.sftp_username}/upload/incoming/transactions_2025-10-11.csv
    ID,ClientID,Transaction,Amount,Date,Status
    T0005,C001,D,300.00,2025-10-10,Completed
    T0006,C002,W,50.00,2025-10-10,Completed
    CSV

    chown -R ${var.sftp_username}:${var.sftp_username} /sftp/${var.sftp_username}/upload
  EOF
}

resource "aws_instance" "sftp" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sftp.id]

  user_data = local.user_data

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_eip_association" "assoc" {
  instance_id   = aws_instance.sftp.id
  allocation_id = aws_eip.this.id
}

output "public_ip" { value = aws_eip.this.public_ip }
output "public_dns" { value = aws_instance.sftp.public_dns }
output "sftp_user" { value = var.sftp_username }
