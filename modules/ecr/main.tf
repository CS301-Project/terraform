resource "aws_ecr_repository" "client" {
  name                 = "client-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }

  # lifecycle {
  #   prevent_destroy = true
  # }

}

resource "aws_ecr_repository" "account" {
  name                 = "account-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }

  # lifecycle {
  #   prevent_destroy = true
  # }

}

# Lifecycle policy to keep only last 5 images
resource "aws_ecr_lifecycle_policy" "client" {
  repository = aws_ecr_repository.client.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "account" {
  repository = aws_ecr_repository.account.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}