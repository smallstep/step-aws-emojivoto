# AWS Emojivoto
The following example uses step to securely deploy [Emojivoto](https://github.com/buoyantio/emojivoto) microservice to AWS using mTLS. We'll be using the following technologies:

* AWS to host the example
* Puppet for machine-level provisioning
* Terraform to configure the infrastructure
* Envoy to handle TLS termination
* step certificates & step SDS for certificate management

## Microservices Deployment Architecture

This example will use automation to provision an instance of [Emojivoto](https://github.com/buoyantio/emojivoto).

```
          +--------------+
          |    BROWSER   |
          +------+-------+
                 |
                 |TLS
                 |
          +------+-------+
          |    ENVOY     |
          |      |       |                 +------------+
          |     WEB      |                 |            |
          |      |       |    TLS+mTLS     |     CA     |
          |    ENVOY--SDS+-----------------+            |
          +------+-------+                 +-----+------+
                 |                               |
                 |                               |
                 |                               |TLS+mTLS
         mTLS    |   mTLS                        |
      +----------+----------+                    |
      |                     |                    |
      |                     |                    |
+-----+-------+       +-----+--------+           |
|   ENVOY     |       |   ENVOY      |           |
|     |       |       |              |           |
|   EMOJI--SDS|       |   VOTING--SDS+-----------+
+-----------+-+       +--------------+           |
            |                                    |
            |                                    |
            |                                    |
            +------------------------------------+
```

* Emojivoto as is does not support (m)TLS
* Every service in the diagram above will run on its own dedicated VM (EC2 instance) in AWS.
* An Envoy sidecar proxy (ingress & egress) per service will handle mutual TLS (authentication & encryption).
* Envoy sidecars obtain certificates through the *[secret discovery service](https://www.envoyproxy.io/docs/envoy/latest/configuration/secret)* (step SDS) exposed via a local UNIX domain socket.
* Step SDS will fetch a certificate, as well as the trust bundle (root certificate), from the internal Certificate Authority (learn more at [step certificates](https://github.com/smallstep/certificates)) on behalf of each service/sidecar pair.
* Step SDS will handle renewals for certificates that are nearing the end of their lifetimes.

## Step-by-Step Setup Instructions

This AWS example integration will use full automation to provision infrastructure, machines, and services from scratch. While there are a plethora of tools availabe, Terraform & Puppet were chosen for provisioning. Before kicking off the provisioning process we need to configure AWS (account credentials & permissions), SSH, and Terraform.

### AWS CLI

Install and configure the AWS CLI. AWS has instructions for installing the CLI on various platforms at: [https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).

Once installed, grab AWS credentials from your account or AWS IAM (depends on what you're using) and follow the interactive steps of the `configure` command. [AWS's documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) has detailed instructions on how to get AWS credentials. Make sure the credentials granted the IAM policies `AmazonEC2FullAccess`, `AmazonVPCFullAccess`, and `AmazonRoute53FullAccess` (broad permissions) or at the minimum permissions as per the [policy file included in the repo](policy.json).

```bash
$ aws configure
AWS Access Key ID []: ****************UJ7U
AWS Secret Access Key []: ****************rUg8
Default region name []: us-west-1
Default output format []: json
$ aws s3 ls
# should list S3 buckets if the account has any
2017-10-26 13:50:39 smallstep-not-a-real-bucket
2017-10-26 15:43:20 smallstep-fake-bucket
2018-04-09 17:25:18 smallstep-nobody-home
```

### SSH Key Pair

Terraform requires a key pair to be used for provisioning EC2 machine instances. Any key pair available in the respective region will work as long as the local terraform/puppet process has access to the key pair's private key. Please see the [AWS EC2 Key Pairs documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) for details on how to manage key pairs in AWS.

The EC2 key pair will likely be available as a single file in `PEM` format. Use the following commands to convert the `PEM` and place the resulting files in locations where terraform and puppet can locate them.

```bash
$ chmod 400 aws-e2e-howto.pem
# we will need the public key in terraform config
$ ssh-keygen -f aws-e2e-howto.pem -y > ~/.ssh/terraform.pub
# the private key is already in the correct format
$ cp aws-e2e-howto.pem ~/.ssh/terraform
# new files only readable by owner (not encrypted on disk!)
$ chmod 400 ~/.ssh/terraform*
```

> Note: It's not required to use key pairs generated by AWS. `ssh-keygen` will work for anybody who's familiar and prefers local key generation.

### Terraform

Before running the `init` command Terraform needs to be configured with your ssh public key.

```bash
diff --git a/aws-emojivoto/emojivoto.tf b/aws-emojivoto/emojivoto.tf
index b510dcb..33ff92d 100644
--- a/aws-emojivoto/emojivoto.tf
+++ b/aws-emojivoto/emojivoto.tf
@@ -17,7 +17,7 @@ provider "aws" {
 # Create an SSH key pair to connect to our instances
 resource "aws_key_pair" "terraform" {
   key_name   = "terraform-key"
-  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCVEhUwiAivgdFuu5rOv8ArAMqTA6N56yd5RA+uHdaC0e4MM3TYhUOwox0fV+opE3OKLYdG2+mF/6Z4k8PgsBxLpJxdQ9XHut3A9WoqCEANVfZ7dQ0mgJs1MijIAbVg1kXgYTg/2iFN6FCO74ewAJAL2e8GqBDRkwIueKbphmO5U0mK3d/nnLK0QSFYgQGFGFHvXkeQKus+625IHifat/GTZZmhCxZBcAKzaAWB8dSaZGslaKsixy3EGiY5Gqdi5tQvt+obxZ59o4Jk352YlxhlUSxoxpeOyCiBZkexZgm+0MbeBrDuOMwg/tpcUiJ0/lVomx+dQuIX6ciKIuwnvDhx"
+  public_key = "<SSH Public Key, as in ~/.ssh/terraform.pub>"
 }

 variable "ami" {
```

Once AWS CLI and Terraform CLI & definitions are in place, we can initialize the workspace on the Terraform backend:

```bash
$ terraform init
Initializing the backend...

Successfully configured the backend "local"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...

Terraform has been successfully initialized!
[...]
```

Now Terraform is ready to go. The `apply` command will print out a long execution plan of all the infrastructure that will be created. Terraform will prompt for a confirmation (type `yes`) before executing on the plan. Please note: The completion of this process can take some time.

```bash
$ terraform apply

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_instance.ca will be created
  + resource "aws_instance" "ca" {
      + ami                          = "ami-068670db424b01e9a"
      + arn                          = (known after apply)
      + associate_public_ip_address  = true
      + availability_zone            = (known after apply)
      + cpu_core_count               = (known after apply)
      + cpu_threads_per_core         = (known after apply)
      + get_password_data            = false
      + host_id                      = (known after apply)
      + id                           = (known after apply)
      + instance_state               = (known after apply)
      + instance_type                = "t2.micro"
      + ipv6_address_count           = (known after apply)
      + ipv6_addresses               = (known after apply)
      + key_name                     = "terraform-key"
      + network_interface_id         = (known after apply)
      + password_data                = (known after apply)
      + placement_group              = (known after apply)
      + primary_network_interface_id = (known after apply)
      + private_dns                  = (known after apply)
      + private_ip                   = (known after apply)
      + public_dns                   = (known after apply)
      + public_ip                    = (known after apply)
      + security_groups              = (known after apply)
      + source_dest_check            = true
      + subnet_id                    = (known after apply)
      + tags                         = {
          + "Name" = "emojivoto-ca"
        }
      + tenancy                      = (known after apply)

  [...]
    }

Plan: 21 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

After some wait time Terraform will confirm the successful completion, printing out details about the newly created infrastructure:

```bash
[...]
aws_instance.web (remote-exec): Info: Creating state file /var/cache/puppet/state/state.yaml
aws_instance.web (remote-exec): Notice: Applied catalog in 39.59 seconds
aws_instance.web (remote-exec): + sudo puppet agent --server puppet.emojivoto.local
aws_instance.web: Creation complete after 2m6s [id=i-0481e26a14f8f74b8]
aws_route53_record.web: Creating...
aws_route53_record.web: Still creating... [10s elapsed]
aws_route53_record.web: Still creating... [20s elapsed]
aws_route53_record.web: Still creating... [30s elapsed]
aws_route53_record.web: Still creating... [40s elapsed]
aws_route53_record.web: Creation complete after 47s [id=ZIAUV5309R860_web.emojivoto.local_A]

Apply complete! Resources: 21 added, 0 changed, 0 destroyed.

Outputs:

ca_ip = 13.57.209.0
emoji_ip = 54.183.41.170
puppet_ip = 54.183.255.218
voting_ip = 54.153.37.230
web_ip = 13.52.182.175
```

## Explore Emojivoto on AWS

AWS Emojivoto is using internal DNS records to resolve hosts for inter-service communication. All TLS certificates are issued for (SANs) the respective DNS name, e.g. `web.emojivoto.local` or `voting.emojivoto.local` (please see [dns.tf](dns.tf) for details).

For this to work on machines without managed external DNS the hostname/IP address mapping needs to be added to `/etc/hosts` so that hostnames can be verified against server certificates.

```bash
$ cat /etc/hosts
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
169.254.169.254 metadata.google.internal  # Added by Google

13.52.182.175    web.emojivoto.local
```

AWS Emojivoto leverages an internal CA to secure communication between services so every client must specify the root certificate (`root_ca.crt`) of the internal CA to trust it explicitly.

### Using Step CLI

```
$ step certificate inspect --roots root_ca.crt --short https://web.emojivoto.local
X.509v3 TLS Certificate (ECDSA P-256) [Serial: 1993...2666]
  Subject:     web.emojivoto.local
  Issuer:      Smallstep Test Intermediate CA
  Provisioner: step-sds [ID: Z2S-...gK6U]
  Valid from:  2019-07-25T21:13:35Z
          to:  2019-07-26T21:13:35Z
```

### Using cURL

```bash
$ curl -I --cacert root_ca.crt https://web.emojivoto.local
HTTP/1.1 200 OK
content-type: text/html
date: Fri, 26 Jul 2019 00:27:02 GMT
content-length: 560
x-envoy-upstream-service-time: 0
server: envoy

# without --cacert specifying the root cert it will fail (expected)
$ curl -I root_ca.crt https://web.emojivoto.local
curl: (6) Could not resolve host: root_ca.crt
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.haxx.se/docs/sslcerts.html

curl performs SSL certificate verification by default, using a "bundle"
 of Certificate Authority (CA) public keys (CA certs). If the default
 bundle file isn't adequate, you can specify an alternate file
 using the --cacert option.
[...]
```

### Using a browser

Navigating a browser to [`https://web.emojivoto.local/`](https://web.emojivoto.local/) will result in a big alert warning that **`Your connection is not private`**. The reason for the alert is `NET::ERR_CERT_AUTHORITY_INVALID` which a TLS error code. The error code means that the certificate path validation could not be verified against the locally known root certificates in the trust store. Since the TLS cert for AWS Emojivoto's web service is **not** using `Public Web PKI` this is expected. Beware of these warnings. In this particular case where we're using an internal CA it's safe to `Proceed to web.emojivoto.local` under the `Advanced` menu.

It is possible to avoid the TLS warning by installing the internal CA's root certificate into your local trust store. The step CLI has a command to do exactly that:

```bash
$ sudo step certificate install root_ca.crt
Certificate root_ca.crt has been installed.
X.509v3 Root CA Certificate (ECDSA P-256) [Serial: 1038...4951]
  Subject:     Smallstep Test Root CA
  Issuer:      Smallstep Test Root CA
  Valid from:  2019-07-12T22:14:14Z
          to:  2029-07-09T22:14:14Z
# Navigate browser to https://web.emojivoto.local without warning
$ sudo step certificate uninstall root_ca.crt
Certificate root_ca.crt has been removed.
X.509v3 Root CA Certificate (ECDSA P-256) [Serial: 1038...4951]
  Subject:     Smallstep Test Root CA
  Issuer:      Smallstep Test Root CA
  Valid from:  2019-07-12T22:14:14Z
          to:  2029-07-09T22:14:14Z
# Remove root cert from local trust store. Warning will reappear
```

## That's it!
Thank you. We would love to hear about your experience and welcome [pull requests](https://github.com/smallstep). The team continues to innovate on our offerings and new features are coming every couple of weeks so please check back often to follow our progress. Alternatively you can [subscribe](https://smallstep.com/subscribe/) to our updates here.
