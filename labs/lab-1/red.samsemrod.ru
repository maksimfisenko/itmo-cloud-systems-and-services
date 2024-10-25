server {
    listen 80;
    server_name red.samsemrod.ru;
    return 301 https://$host:8443$request_uri;
}

server {
    listen 8443 ssl;
    server_name red.samsemrod.ru;

    ssl_certificate /etc/letsencrypt/live/red.samsemrod.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/red.samsemrod.ru/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root /var/www/red.samsemrod.ru;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /images/ {
        alias /var/www/red.samsemrod.ru/;
    }
}
