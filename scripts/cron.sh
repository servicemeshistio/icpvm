cat <<EOF > /etc/cron.d/letencrypt
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
30 2 * * * root /usr/bin/certbot renew --deploy-hook /root/bin/letsencrypt/deploy.sh
EOF