resource "tls_private_key" "key" {
    algorithm = "RSA"
    rsa_bits  = 4096
}

resource "aws_key_pair" "key" {
    key_name   = format("%s-Bastion-SSH-Key", module.parameter.application)
    public_key = tls_private_key.key.public_key_openssh
}
