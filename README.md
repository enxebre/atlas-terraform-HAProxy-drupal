HAProxy, Drupal and Mysql
===================
This repository and walkthrough guides you through deploying HAProxy, Apache serving a Drupal8 site using a Mysql server on AWS based on other [examples](https://github.com/hashicorp/atlas-examples).

General setup
-------------
1. Clone this repository
2. Create an [Atlas account](https://atlas.hashicorp.com/account/new?utm_source=github&utm_medium=examples&utm_campaign=haproxy-drupal8-mysql)
3. Generate an [Atlas token](https://atlas.hashicorp.com/settings/tokens) and save as environment variable. 
`export ATLAS_TOKEN=<your_token>`
4. In the Vagrantfile, Packer files `haproxy.json` and `apache-php.json`, `mysql.json`, Terraform file `infrastructure.tf`, and Consul upstart script `consul_client.conf` you need to replace all instances of `<username>`,  `YOUR_ATLAS_TOKEN`, `YOUR_SECRET_HERE`, and `YOUR_KEY_HERE` with your Atlas username, Atlas token, and AWS keys.

Introduction and Configuring HAProxy + Drupal + Mysql
-----------------------------------------------
Before jumping into configuration steps, it's helpful to have a mental model for how services connect and how the Atlas workflow fits in. 

For HAProxy to work properly, it needs to have a real-time list of backend nodes to balance traffic between. In this example, HAProxy needs to have a real-time list of healthy php nodes. To accomplish this, we use [Consul](https://consul.io) and [Consul Template](https://github.com/hashicorp/consul-template). Any time a server is created, destroyed, or changes in health state, the HAProxy configuration updates to match by using the Consul Template `haproxy.ctmpl`. Pay close attention to the backend stanza:

```
backend webs
    balance roundrobin
    mode http{{range service "php.web"}}
    server {{.Node}} {{.Address}}:{{.Port}}{{end}}
```

Consul Template will query Consul for all web servers with the tag "php", and then iterate through the list to populate the HAProxy configuration. When rendered, `haproxy.cfg` will look like:

```
backend webs
    balance roundrobin
    mode http
    server node1 172.29.28.10:8888
    server node2 172.56.28.10:8888
```
This setup allows us to destroy and create backend servers at scale with confidence that the HAProxy configuration will always be up-to-date. You can think of Consul and Consul Template as the connective webbing between services. 

Consul Template will query Consul for all "database" servers with the tag "mysql", and then iterate through the list to populate the PHP/Drupal configuration. When rendered, `settings.php` will look like:

```
$databases = array();
$databases['default']['default'] = array(
    'driver' => 'mysql',
    'database' => 'drupal',
    'username' => 'apache',
    'password' => 'password',
    'host' => '172.56.28.10',
    'prefix' => '',
);
```
This setup allows us to destroy and create Apache+PHP serving drupal with confidence that their configurations will always be correct and they will always write to the proper MySQL instances. You can think of Consul and Consul Template as the connective webbing between services. 

Step 1: Create a Consul Cluster
-------------------------
1. For Consul Template to work for HAProxy, we first need to create a Consul cluster. You can follow [this walkthrough](https://github.com/hashicorp/atlas-examples/tree/master/consul) to guide you through that process. 

Step 2: Build an HAProxy AMI
----------------------------
1. Build an AMI with HAProxy installed. To do this, run `packer push -create haproxy.json` in the HAProxy packer directory. This will send the build configuration to Atlas so it can build your HAProxy AMI remotely. 
2. View the status of your build in the Operations tab of your [Atlas account](atlas.hashicorp.com/operations).

Step 3: Build a Drupal AMI
--------------------------
1. Build an AMI with the Drupal requirements Apache, PHP, [Composer](https://getcomposer.org/) and [drush](http://www.drush.org/en/master/) installed. To do this, run `packer push -create apache-php.json` in the ops directory. This will send the build configuration to Atlas so it can remotely build your AMI with Apache and PHP installed.
2. View the status of your build in the Operations tab of your [Atlas account](atlas.hashicorp.com/operations).
3. This creates an AMI with Apache and PHP installed, and now you need to send the actual Drupal application code to Atlas and link it to the build configuration. To do this, put your Drupal code in the app folder or follow instructions [here](https://www.drupal.org/project/drupal/git-instructions) for cloning a clean drupal installation and simply run `vagrant push` in the app directory. This will send your full Drupal application code to Atlas. Then link the Drupal application with the Apache+PHP build configuration by clicking on your build configuration, then 'Links' in the left navigation. Complete the form with your username, 'drupal' as the application name, and '/app' as the destination path.
4. Now that your application and build configuration are linked, simply rebuild the Apache+PHP configuration and you will have a fully-baked AMI with Apache and PHP installed and your Drupal application code in place.

Step 4: Build a MySQL AMI
-------------------------
1. Build an AMI with MySQL installed. To do this, run `packer push -create mysql.json` in the ops directory. This will send the build configuration to Atlas so it can build your MySQL AMI remotely. 
2. View the status of your build in the Operations tab of your [Atlas account](atlas.hashicorp.com/operations).

Step 5: Deploy HAProxy, Drupal and Mysql
----------------------------------------
1. To deploy HAProxy, Drupal and Mysql, all you need to do is run `terraform apply` in the ops/terraform folder. Be sure to run `terraform apply` only on the artifacts first. The easiest way to do this is comment out the `aws_instance` resources and then run `terraform apply`. Once the artifacts are created, just uncomment the `aws_instance` resources and run `terraform apply` on the full configuration. Watch Terraform provision five instances — two with Drupal, one with Mysql and one with HAProxy! 

```
provider "aws" {
    access_key = "YOUR_KEY_HERE"
    secret_key = "YOUR_SECRET_HERE"
    region = "us-east-1"
}

resource "atlas_artifact" "haproxy" {
    name = "<username>/haproxy"
    type = "aws.ami"
}

resource "atlas_artifact" "php" {
    name = "<username>/apache-php"
    type = "aws.ami"
}

resource "atlas_artifact" "mysql" {
    name = "<username>/mysql"
    type = "aws.ami"
}

resource "aws_security_group" "all" {
  name = "haproxy"
    description = "Allow all inbound traffic"

  ingress {
      from_port = 0
      to_port = 65535
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "haproxy" {
    instance_type = "t2.micro"
    ami = "${atlas_artifact.haproxy.metadata_full.region-us-east-1}"
    security_groups = ["${aws_security_group.all.name}"]
    # This will create 1 instance
    count = 1
    lifecycle = {
      create_before_destroy = true  
    }
}

resource "aws_instance" "php" {
    instance_type = "t2.micro"  
    ami = "${atlas_artifact.php.metadata_full.region-us-east-1}"
    security_groups = ["${aws_security_group.all.name}"]
    depends_on = ["aws_instance.mysql"]
    # This will create 2 instance
    count = 2
    lifecycle = {
      create_before_destroy = true
    }
}

resource "aws_instance" "mysql" {
    instance_type = "t2.micro"
    ami = "${atlas_artifact.mysql.metadata_full.region-us-east-1}"
    security_groups = ["${aws_security_group.all.name}"]
    # This will create 1 instances
    count = 1
    lifecycle = {
      create_before_destroy = true  
    }
}
```

Final Step: Test HAProxy
------------------------
1. Navigate to your HAProxy stats page by going to it's Public IP on port 1936 and path /haproxy?stats. For example 52.1.212.85:1936/haproxy?stats
2. In a new tab, hit your HAProxy Public IP on port 8080 a few times. You'll see in the stats page that your requests are being balanced evenly between the drupal nodes. 
3. That's it! You just deployed HAProxy, Drupal8 and Mysql. If you are deploying a clean Drupal installation you can follow steps here for [installing drupal](https://www.drupal.org/documentation/install)
4. Navigate to the [Runtime tab](https://atlas.hashicorp.com/runtime) in your Atlas account and click on the newly created infrastructure. You'll now see the real-time health of all your nodes and services!
