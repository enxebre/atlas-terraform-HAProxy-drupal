# install HAproxy
sudo apt-get install -y haproxy
sudo chmod a+w /etc/rsyslog.conf
echo '$ModLoad imudp' >> /etc/rsyslog.conf
echo '$UDPServerAddress 127.0.0.1' >> /etc/rsyslog.conf
echo '$UDPServerRun 514' >> /etc/rsyslog.conf
sudo service rsyslog restart
sup cp /ops/templates/haproxy.cfg /etc/haproxy/haproxy.cfg

# eve upstart
sudo cp /ops/upstart/haproxy.conf /etc/init/haproxy.conf

# consul config
echo '{"service": {"name": "haproxy", "tags": ["haproxy"]}}' \
    >/etc/consul.d/haproxy.json
sudo cp /ops/upstart/consul_client.conf /etc/init/consul.conf

# install consul template
wget https://github.com/hashicorp/consul-template/releases/download/v0.6.5/consul-template_0.6.5_linux_amd64.tar.gz
tar xzf consul-template_0.6.5_linux_amd64.tar.gz
sudo mv consul-template_0.6.5_linux_amd64/consul-template /usr/bin
sudo rmdir consul-template_0.6.5_linux_amd64

# consul template upstart for haproxy
sudo cp /ops/upstart/consul_template.conf /etc/init/consul_template.conf