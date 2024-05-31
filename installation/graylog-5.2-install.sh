#!/bin/bash

echo "[+] Checking for root permissions"
if [ "$EUID" -ne 0 ];then
    echo "Please run this script as root"
    exit 1
fi

echo "[+] Seeting needrestart to automatic to prevent restart pop ups"
sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

echo "[+] Checking for updates"
apt-get update
apt-get upgrade -y

echo "[+] setting max files for opensearch"
sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf

echo "[+] Installing depenbdancies and MongoDB"
apt-get install dirmngr gnupg apt-transport-https ca-certificates software-properties-common net-tools gnupg curl -y
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
apt-get update
apt-get install -y mongodb-org
systemctl daemon-reload
systemctl enable mongod
systemctl start mongod

echo "[+] Disabling huge pages support"
cat > /etc/systemd/system/disable-transparent-huge-pages.service <<EOF
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null'
[Install]
WantedBy=basic.target
EOF

systemctl daemon-reload
systemctl enable disable-transparent-huge-pages.service
systemctl start disable-transparent-huge-pages.service

echo "[+] Opensearch User"
adduser --system --disabled-password --disabled-login --home /var/empty --no-create-home --quiet --force-badname --group opensearch

echo "[+] Installing Opensearch"
wget https://artifacts.opensearch.org/releases/bundle/opensearch/2.10.0/opensearch-2.10.0-linux-x64.tar.gz

#Create Directories
mkdir -p /opt/graylog/opensearch/data
mkdir /var/log/opensearch

#Extract Contents from tar
tar -zxf opensearch-2.10.0-linux-x64.tar.gz
mv opensearch-2.10.0/* /opt/graylog/opensearch/

#Create empty log file
sudo -u opensearch touch /var/log/opensearch/graylog.log

#Set Permissions
chown -R opensearch:opensearch /opt/graylog/opensearch/
chown -R opensearch:opensearch /var/log/opensearch
chmod -R 2750 /opt/graylog/opensearch/
chmod -R 2750 /var/log/opensearch

#Create System Service

cat > /etc/systemd/system/opensearch.service <<EOF
[Unit]
Description=Opensearch
Documentation=https://opensearch.org/docs/latest
Requires=network.target remote-fs.target
After=network.target remote-fs.target
ConditionPathExists=/opt/graylog/opensearch
ConditionPathExists=/opt/graylog/opensearch/data
[Service]
Environment=OPENSEARCH_HOME=/opt/graylog/opensearch
Environment=OPENSEARCH_PATH_CONF=/opt/graylog/opensearch/config
ReadWritePaths=/var/log/opensearch
User=opensearch
Group=opensearch
WorkingDirectory=/opt/graylog/opensearch
ExecStart=/opt/graylog/opensearch/bin/opensearch
# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=65535
# Specifies the maximum number of processes
LimitNPROC=4096
# Specifies the maximum size of virtual memory
LimitAS=infinity
# Specifies the maximum file size
LimitFSIZE=infinity
# Disable timeout logic and wait until process is stopped
TimeoutStopSec=0
# SIGTERM signal is used to stop the Java process
KillSignal=SIGTERM
# Send the signal only to the JVM rather than its control group
KillMode=process
# Java process is never killed
SendSIGKILL=no
# When a JVM receives a SIGTERM signal it exits with code 143
SuccessExitStatus=143
# Allow a slow startup before the systemd notifier module kicks in to extend the timeout
TimeoutStartSec=180
[Install]
WantedBy=multi-user.target
EOF

echo "[+] Backing up opensearch and creating new one for Graylog"
cp /opt/graylog/opensearch/config/opensearch.yml /opt/graylog/opensearch/config/opensearch-bup.yml
rm /opt/graylog/opensearch/config/opensearch.yml
touch /opt/graylog/opensearch/config/opensearch.yml
chown opensearch:opensearch /opt/graylog/opensearch/config/opensearch.yml
chmod 2750 /opt/graylog/opensearch/config/opensearch.yml

cat > /opt/graylog/opensearch/config/opensearch.yml <<EOF
cluster.name: graylog
node.name: node1
path.data: /opt/graylog/opensearch/data
path.logs: /var/log/opensearch
network.host: 127.0.0.1
discovery.seed_hosts: ["127.0.0.1"]
cluster.initial_master_nodes: ["127.0.0.1"]
action.auto_create_index: false
plugins.security.disabled: true
EOF

echo "[+] Reloading Opensearch Service"
systemctl daemon-reload
systemctl enable opensearch.service
systemctl start opensearch.service

echo "[+] Installing graylog"
wget https://packages.graylog2.org/repo/packages/graylog-5.2-repository_latest.deb
dpkg -i graylog-5.2-repository_latest.deb
apt-get update && sudo apt-get install graylog-server -y

SECRET=`< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-96};echo;`
echo -n "Enter Admin wenb interface Password: "
read passwd
ADMIN=`echo $passwd| tr -d '\n' | sha256sum | cut -d" " -f1`
echo "Generated password salt is " $secret
echo "Genberated admin hash is " $admin

echo "[+] Adjusting Graylog Server configuration file"
CONFIGSECRET=`echo "password_secret = "$SECRET`
CONFIGADMIN=`echo "root_password_sha2 = "$ADMIN`
echo "[+] replacing in configuration files"
sed -r "s/password_secret =/${CONFIGSECRET}/g" -i /etc/graylog/server/server.conf
sed -r "s/root_password_sha2 =/${CONFIGADMIN}/g" -i /etc/graylog/server/server.conf
sed -i 's/#http_bind_address = 127.0.0.1:9000/http_bind_address = 0.0.0.0:9000/g' /etc/graylog/server/server.conf


echo "[+] Disabling Gralog version checks"
echo "versionchecks = false" >> /etc/graylog/server/server.conf

echo "[+] Enabling Graylog"
systemctl daemon-reload
systemctl enable graylog-server.service
chown graylog:graylog /opt/graylog/journal

echo "###################################################################"
echo "## Set your JVM memory options for your server in below          ##"
echo "## /etc/default/graylog-server                                   ##"
echo "## /graylog/opensearch/config/jvm.options.d                      ##"
echo "## After setting, restart elasticsearch and start graylog        ##" 
echo "###################################################################"