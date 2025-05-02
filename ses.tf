resource "aws_ses_configuration_set" "email-verification-configuration-set" {
  name = format("%s-Email-Verification-Configuration-Set", var.name)
  sending_enabled            = true
  reputation_metrics_enabled = true
  delivery_options {
    tls_policy = "Require"
  }
}

resource "aws_ses_configuration_set" "email-mfa-configuration-set" {
  name = format("%s-Email-MFA-Configuration-Set", var.name)
  sending_enabled            = true
  reputation_metrics_enabled = true
  delivery_options {
    tls_policy = "Require"
  }
}

# @TODO Enable better event-driven reporting
resource "aws_ses_event_destination" "email-verification-event-destination" {
  name = format("%s-Email-Verification-Configuration-Set-Destination", var.name)
  enabled = true

  configuration_set_name = aws_ses_configuration_set.email-verification-configuration-set.name
  matching_types = [
    "send",
    "reject",
    "bounce",
    "complaint",
    "delivery",
    "renderingFailure",
    # "open",
    # "click",
  ]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "dimension"
    value_source   = "emailHeader"
  }
}

# @TODO Enable better event-driven reporting
resource "aws_ses_event_destination" "email-mfa-event-destination" {
  name = format("%s-Email-MFA-Configuration-Set-Destination", var.name)
  enabled = true

  configuration_set_name = aws_ses_configuration_set.email-mfa-configuration-set.name
  matching_types = [
    "send",
    "reject",
    "bounce",
    "complaint",
    "delivery",
    "renderingFailure",
    # "open",
    # "click",
  ]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "dimension"
    value_source   = "emailHeader"
  }
}


resource "aws_ses_domain_identity" "domain" {
  domain = var.mail-identity-domain
}

resource "aws_ses_domain_dkim" "domain" {
  domain = aws_ses_domain_identity.domain.domain
}

data "aws_route53_zone" "domain" {
  name = var.mail-identity-domain
}

resource "aws_route53_record" "domain" {
  count   = 3
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "${aws_ses_domain_dkim.domain.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_ses_domain_dkim.domain.dkim_tokens[count.index]}.dkim.amazonses.com"]

  allow_overwrite = true
}

resource "aws_route53_record" "domain-verification-record" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "_amazonses.${aws_ses_domain_identity.domain.id}"
  type    = "TXT"
  ttl     = "300"
  records = [aws_ses_domain_identity.domain.verification_token]
}

resource "aws_ses_domain_identity_verification" "domain-verification" {
  domain = aws_ses_domain_identity.domain.id

  depends_on = [aws_route53_record.domain-verification-record]
}

resource "aws_ses_domain_mail_from" "domain" {
  domain           = aws_ses_domain_identity.domain.domain
  mail_from_domain = "bounce.${aws_ses_domain_identity.domain.domain}"
}

resource "aws_route53_record" "domain-ses-mail-from-mx" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = aws_ses_domain_mail_from.domain.mail_from_domain
  type    = "MX"
  ttl     = "300"
  records = ["10 feedback-smtp.${data.aws_region.region.name}.amazonses.com"]
}

resource "aws_route53_record" "ses-domain-mail-from-txt"{
  zone_id = data.aws_route53_zone.domain.zone_id

  name    = aws_ses_domain_mail_from.domain.mail_from_domain
  type    = "TXT"
  ttl     = "300"
  records = ["v=spf1 include:amazonses.com -all"]
}

resource "aws_route53_record" "dmarc-records" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "_dmarc.${var.mail-identity-domain}"
  type    = "TXT"
  ttl     = "300"

  records = [
    #@TODO Enable additional DMARC settings such as rua, ruf, fo
    "v=DMARC1; p=none;"# "v=DMARC1; p=none; rua=mailto:${var.dmarc_report_address}; ruf=mailto:${var.dmarc_forensic_address}; fo=1;",
  ]
}
