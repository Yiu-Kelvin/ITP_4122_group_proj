resource "aws_acm_certificate" "cert" {
  domain_name               = "school.pikaamail.com"
  subject_alternative_names = ["myportal.pikaamail.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "moodle" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = "Z0111437GSSD0Z667NKN"
}

resource "aws_route53_record" "myportal-load-balancer" {
  zone_id = "Z0111437GSSD0Z667NKN"
  name    = "myportal.pikaamail.com"
  type    = "CNAME"
  ttl     = "300"

  records = [data.kubernetes_resources.ingress.objects.0.status.loadBalancer.ingress.0.hostname]
}

resource "aws_route53_record" "moodle-load-balancer" {
  zone_id = "Z0111437GSSD0Z667NKN"
  name    = "school.pikaamail.com"
  type    = "CNAME"
  ttl     = "300"

  records = [data.kubernetes_resources.ingress.objects.0.status.loadBalancer.ingress.0.hostname]
}