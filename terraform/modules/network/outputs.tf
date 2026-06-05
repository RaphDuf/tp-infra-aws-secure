output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id_a" {
  value = aws_subnet.private_a.id
}

output "private_subnet_id_b" {
  value = aws_subnet.private_b.id
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}
