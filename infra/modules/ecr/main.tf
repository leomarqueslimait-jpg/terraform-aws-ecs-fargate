
resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Name = "${var.name}-ecr-repository" })
}

resource "terraform_data" "push_image" {
  depends_on = [aws_ecr_repository.this]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.this.repository_url} && \
docker build -t ${aws_ecr_repository.this.repository_url}:${var.image_tag} ${var.app_path} && \
docker push ${aws_ecr_repository.this.repository_url}:${var.image_tag}
EOF
  }
}