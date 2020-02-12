#!/bin/bash

CF_EMAIL=<CF_EMAIL>
CF_API_KEY=<CF_API>
CF_DOMAIN_ID=<CF_DOMAIN_ID>
DOMAIN=$1
DBNAME=$(echo $1 | cut -d '.' -f1)
DBUSER=$DBNAME
DBPASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12)
#NAMECHEAP API


#CLOUDFLARE API
MYIP=$(dig @resolver1.opendns.com ANY myip.opendns.com +short)
CF_DM_ID=$(curl -X POST "https://api.cloudflare.com/client/v4/zones" \
     -H "X-Auth-Email: $CF_EMAIL" \
     -H "X-Auth-Key: $CF_API_KEY" \
     -H "Content-Type: application/json" \
     --data '{"name":"'$DOMAIN'","account":{"id":"'$CF_DOMAIN_ID'"},"jump_start":true,"type":"full"}'| jq -r .result.id)

curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_DM_ID/dns_records" \
     -H "X-Auth-Email: $CF_EMAIL" \
     -H "X-Auth-Key: $CF_API_KEY" \
     -H "Content-Type: application/json" \
     --data '{"type":"A","name":"'$DOMAIN'","content":"'$MYIP'","ttl":1,"proxied":true}'

curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_DM_ID/dns_records" \
     -H "X-Auth-Email: $CF_EMAIL" \
     -H "X-Auth-Key: $CF_API_KEY" \
     -H "Content-Type: application/json" \
     --data '{"type":"A","name":"www","content":"'$DOMAIN'","ttl":1,"proxied":true}'

#NGINX
nginx_create () {
cp /opt/autopress/$1 /etc/nginx/sites-enabled/$DOMAIN
sed -i 's/KX_DOMAINNAME/'$DOMAIN'/g' /etc/nginx/sites-enabled/$DOMAIN
nginx -t
if [ $? -ne 0 ]; then
    echo "NGINX CHECK FAILED"
    exit 2
fi
service nginx reload
}

nginx_create virtualhost-sample

#CERTBOT SSL
certbot certonly -w /var/www/html/$DOMAIN -d $DOMAIN -d www.$DOMAIN --webroot
nginx_create virtualhost-ssl-sample

#CREATE DATABASE
mysql -e "CREATE DATABASE ${DBNAME} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
mysql -e "CREATE USER '${DBUSER}'@'%' IDENTIFIED BY '${DBPASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'%';"
mysql -e "FLUSH PRIVILEGES;"

#WORDPRESS
wget https://wordpress.org/latest.tar.gz -P /var/www/html/
cd /var/www/html && tar -xzvf latest.tar.gz && mv wordpress $DOMAIN
rm /var/www/html/latest.tar.gz
cp /opt/autopress/wp-config-sample /var/www/html/$DOMAIN/wp-config.php

sed -i 's/KX_DBNAME/'$DBNAME'/g' /var/www/html/$DOMAIN/wp-config.php
sed -i 's/KX_DBUSER/'$DBUSER'/g' /var/www/html/$DOMAIN/wp-config.php
sed -i 's/KX_DBPASS/'$DBPASS'/g' /var/www/html/$DOMAIN/wp-config.php


