terraform {
  backend "remote" {
    organization = "Smallstep"

    workspaces {
      name = "Emojivoto"
    }
  }
}

# Define the provider that we are going to use
provider "aws" {
  profile = "default"
  region  = "us-west-1"
}

# Create an SSH key pair to connect to our instances
resource "aws_key_pair" "terraform" {
  key_name   = "terraform-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7YNXWbeBVIkF8jtgtyg9UZPVYYXUTiFvfvk/q8GSroV3ITesNi0s7Hpq/GDuudNlGMZ2YruLG1pw8yJ+uBAd36W1EWJgd2FP1f0tMoqALiTC2pMvxbs2F/7Q3XxPOAS2RjndZvkemiTIl5g1qn0LdI2LO1kEPJAcUxNX3mwLMB06Ja5vg43qXaSc6xfYIeqFJhWYLaVTKOECUydK2WHVfwn5cBJU2bhu5ACUGoXSM+DWqFiM1BndrBG+7+5KxfLKFDG079dOOCvE6wsyJ7Gik46dcn8BzV1Ar356Pf9MtrfNl9y9B6xfr+404h0dG5ek5DbhiMzwW9rQ+VXHr3oqtJPVhK2p+5U9kedoaAxO4gVnjkfyStAlI/VKCcxmRffjli0ddOyabSoXLnVThc7MKBbYZG9ndUwml6m+RTDw7g5UZljQiF+iGcc65UmdhZt88ixZa83DslmRksoPxcltNFSh+VvrOJYOK5rjY015SSUzHBIadnM76lwlbyx32QxJDpzGQNqwQ/dSGtLEsSwXFGMwn+LpcWhx79AOfcRePyg8dl9NrAs5HbFI3ujSf5rZGnzsEh9lYk5E3OCNqrXA29RJ3hmwJijSTtP3JT6gNXkLjvGcFvswJp8B0eF58hf+9KlinmZ8pXLZGBYOj0JiEYeux+PVjwLUQz6/EDr9edQ== mariano@smallstep.com"
}

variable "ami" {
  type    = string
  default = "ami-068670db424b01e9a"
}

variable "key_name" {
  type    = string
  default = "terraform-key"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

output "puppet_ip" {
  value = aws_instance.puppet.public_ip
}

output "ca_ip" {
  value = aws_instance.ca.public_ip
}

output "web_ip" {
  value = aws_instance.web.public_ip
}

output "emoji_ip" {
  value = aws_instance.emoji.public_ip
}

output "voting_ip" {
  value = aws_instance.voting.public_ip
}