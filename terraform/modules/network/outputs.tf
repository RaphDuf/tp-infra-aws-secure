output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public_a.id
}

# >>> A COMPLETER : private_subnet_ids (liste, multi-AZ), etc.
