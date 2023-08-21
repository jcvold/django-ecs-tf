resource "aws_ecs_cluster" "sandbox" {
  name = "${var.ecs_cluster_name}-cluster"
}

resource "aws_launch_configuration" "ecs" {
  name                        = "${var.ecs_cluster_name}-cluster"
  image_id                    = data.aws_ssm_parameter.aws-amzn2023-linux-ami.value
  instance_type               = var.instance_type
  security_groups             = [aws_security_group.ecs.id]
  iam_instance_profile        = aws_iam_instance_profile.ecs.name
  key_name                    = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = true
  user_data                   = "#!/bin/bash\necho ECS_CLUSTER='${var.ecs_cluster_name}-cluster' > /etc/ecs/ecs.config"

  lifecycle {
    create_before_destroy = true
  }
}

# data "template_file" "app" {
#   template = templatefile("templates/django_app.json.tpl")

#   vars = {
#     docker_image_url_django = var.docker_image_url_django
#     region                  = var.region
#   }
# }

resource "aws_ecs_task_definition" "app" {
  family = "django-app"
  container_definitions = templatefile("templates/django_app.json.tpl",
    {
      docker_image_url_django = var.docker_image_url_django
      region                  = var.region
  })
}

resource "aws_ecs_service" "sandbox" {
  name            = "${var.ecs_cluster_name}-service"
  cluster         = aws_ecs_cluster.sandbox.id
  task_definition = aws_ecs_task_definition.app.arn
  iam_role        = aws_iam_role.ecs-service-role.arn
  desired_count   = var.app_count
  depends_on      = [aws_alb_listener.ecs-alb-http-listener, aws_iam_role_policy.ecs-service-role-policy]

  load_balancer {
    target_group_arn = aws_alb_target_group.default-target-group.arn
    container_name   = "django-app"
    container_port   = 8000
  }
}

data "aws_ssm_parameter" "aws-amzn2023-linux-ami" {
  # Returns the latest Amazon Linux 2 ami  
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}
