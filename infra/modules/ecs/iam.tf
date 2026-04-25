#json trust policy
data "aws_iam_policy_document" "ecs_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
#attachment of permission policy
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#2nd permission policy -data block
data "aws_iam_policy_document" "secrets" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.secrets_arn]
  }
}

resource "aws_iam_role_policy" "secrets" {
  role   = aws_iam_role.execution.name
  policy = data.aws_iam_policy_document.secrets.json
}


resource "aws_iam_role" "execution" {
  name               = "ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json
}

resource "aws_iam_role" "task" {
  name               = "ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json
}