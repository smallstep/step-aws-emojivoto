resource "aws_route53_zone" "emojivoto" {
  name = "emojivoto.local"
  vpc {
    vpc_id = "${aws_vpc.emojivoto.id}"
  }
}

resource "aws_route53_record" "puppet" {
  zone_id = "${aws_route53_zone.emojivoto.zone_id}"
  name    = "puppet.emojivoto.local"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.puppet.private_ip}"]
}

resource "aws_route53_record" "ca" {
  zone_id = "${aws_route53_zone.emojivoto.zone_id}"
  name    = "ca.emojivoto.local"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.ca.private_ip}"]
}

resource "aws_route53_record" "web" {
  zone_id = "${aws_route53_zone.emojivoto.zone_id}"
  name    = "web.emojivoto.local"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.web.private_ip}"]
}

resource "aws_route53_record" "emoji" {
  zone_id = "${aws_route53_zone.emojivoto.zone_id}"
  name    = "emoji.emojivoto.local"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.emoji.private_ip}"]
}

resource "aws_route53_record" "voting" {
  zone_id = "${aws_route53_zone.emojivoto.zone_id}"
  name    = "voting.emojivoto.local"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.voting.private_ip}"]
}
