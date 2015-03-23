# install apache php
sudo apt-get -y update

sudo apt-get install -y -qq \
	php5 \
	php5-mysql \
	apache2 \
    php5-gd

# install composer
sudo curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /bin/composer

# install drush
sudo composer global require drush/drush:dev-master
sudo ln -sf /root/.composer/vendor/bin/drush /bin/

# move application files to apache folder
sudo mv /application/app/* /var/www/html

# consul config
echo Configuring Consul....
sudo mv /ops/configs/consul_apache_php.json /etc/consul.d/apache-php.json
sudo mv /ops/upstart/consul_client.conf /etc/init/consul.conf

# install consul template
wget https://github.com/hashicorp/consul-template/releases/download/v0.6.5/consul-template_0.6.5_linux_amd64.tar.gz
tar xzf consul-template_0.6.5_linux_amd64.tar.gz
sudo mv consul-template_0.6.5_linux_amd64/consul-template /usr/bin
sudo rmdir consul-template_0.6.5_linux_amd64

# consul template upstart for apache
sudo cp /ops/upstart/php_consul_template.conf /etc/init/php_consul_template.conf

# drupal default config file
sudo cp /ops/upstart/drupal_consul_template.conf /etc/init/drupal_consul_template.conf
