NGINX_CONFIG=$(cat <<'EOF'
user  nginx;
worker_processes  <worker_processes>;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
    server {

        listen 80;
        server_name <server_name>;
        #ssl_cert

        location /{
                proxy_set_header HOST $host;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_pass http://localhost:8000/;
        }
        location ~* \.(gif|png|jpe?g)$ {
          expires 7d;
          add_header Pragma public;
          add_header Cache-Control "public, must-revalidate, proxy-revalidate";

          # prevent hotlink
          valid_referers none blocked ~.google. ~.bing. ~.yahoo. server_names ~($host);
          if ($invalid_referer) {
            rewrite (.*) /static/images/hotlink-denied.jpg redirect;
            # drop the 'redirect' flag for redirect without URL change (internal rewrite)
          }
        }

        # stop hotlink loop
        location = /static/images/hotlink-denied.jpg { }
    }
}

EOF
)
