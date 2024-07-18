provider "aws" {
  region = "eu-west-1"
}

# S3 Bucket for CodePipeline Artifacts
resource "aws_s3_bucket" "pipeline_artifact_bucket" {
  bucket = "my-pipeline-artifact-bucket"
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_service_role" {
  name               = "codepipeline-service-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com",
        },
        Action = "sts:AssumeRole",
      }
    ],
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  role   = aws_iam_role.codepipeline_service_role.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:*", "codebuild:*", "codedeploy:*"],
        Resource = "*",
      }
    ],
  })
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_service_role" {
  name               = "codebuild-service-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com",
        },
        Action = "sts:AssumeRole",
      }
    ],
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role   = aws_iam_role.codebuild_service_role.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:*", "logs:*"],
        Resource = "*",
      }
    ],
  })
}

# IAM Role for CodeDeploy
resource "aws_iam_role" "codedeploy_service_role" {
  name               = "codedeploy-service-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codedeploy.amazonaws.com",
        },
        Action = "sts:AssumeRole",
      }
    ],
  })
}

resource "aws_iam_role_policy" "codedeploy_policy" {
  role   = aws_iam_role.codedeploy_service_role.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:*", "ec2:*", "autoscaling:*", "codedeploy:*", "logs:*"],
        Resource = "*",
      }
    ],
  })
}

# CodeBuild Project
resource "aws_codebuild_project" "my_codebuild_project" {
  name         = "MyCodeBuildProject"
  service_role = aws_iam_role.codebuild_service_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:4.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type = "CODEPIPELINE"
  }
}

# CodeDeploy Application
resource "aws_codedeploy_app" "my_codedeploy_application" {
  name = "MyCodeDeployApplication"
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "my_codedeploy_deployment_group" {
  app_name              = aws_codedeploy_app.my_codedeploy_application.name
  deployment_group_name = "MyDeploymentGroup"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      value = "MyEC2Instance"
      type  = "KEY_AND_VALUE"
    }
  }

  deployment_config_name = "CodeDeployDefault.OneAtATime"
}

# CodePipeline
resource "aws_codepipeline" "my_pipeline" {
  name     = "MyPipeline"
  role_arn = aws_iam_role.codepipeline_service_role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.pipeline_artifact_bucket.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      configuration = {
        S3Bucket    = "my-source-bucket"
        S3ObjectKey = "source.zip"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.my_codebuild_project.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildArtifact"]
      configuration = {
        ApplicationName     = aws_codedeploy_app.my_codedeploy_application.name
        DeploymentGroupName = aws_codedeploy_deployment_group.my_codedeploy_deployment_group.name
      }
    }
  }
}
