resource "aws_iam_role" "marketwatch_ec2" {
  name = "MarketWatchEC2Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "marketwatch_ecr_pull" {
  name = "MarketWatchECRPull"
  role = aws_iam_role.marketwatch_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = aws_ecr_repository.marketwatch.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "marketwatch_ec2" {
  name = "MarketWatchEC2Profile"
  role = aws_iam_role.marketwatch_ec2.name
}