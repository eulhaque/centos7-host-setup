#!/bin/bash

source "./commons.sh"
source "./nginx_config.sh"
source "./fail2ban_config.sh"

ip=$(ip addr show | grep inet | grep eht0 | awk '{print $2}' | cut -d '/' -f 1)
hostname=$(hostname)
installer="yum"
pythonversion="3.6.2"

echo "Host IP Address is: $ip HostName: $hostname"

echo "Updating $installer repos"
$installer update

function install_python {
    cwd=$(pwd)
    echo "===== Installing python-3.6 ======"
    echo "installing development tools"
    $installer groupinstall -y 'development tools'

    echo "Installing required packages"
    $installer install -y zlib-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel bzip2-devel

    echo "Downloading python-${python-version}"
    cd /tmp/ && wget https://www.python.org/ftp/python/${pythonversion}/Python-${pythonversion}.tgz && tar xvf Python-${pythonversion}.tgz

    cd Python-${pythonversion}/
    ./configure --prefix=/usr/local --enable-unicode=ucs4 --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib"

    make
    echo "Running make altinstall"
    make altinstall

    export PATH="/usr/local/bin:$PATH"

    echo "Removing tmp files and installed dirs"
    rm -r Python-*

    cd $cwd
    echo "========== Completed Python-${python-version} Install ============"
}

function setup_python_app {

    echo "Setting up basic python app"
    app=$(cat <<EOF
#!/usr/local/bin/python3.6

import flask

app = flask.Flask(__name__)

@app.route('/')
def index():

    return flask.make_response('Hello World', 200)
EOF
)
    echo "$app" > helloworld.py

    echo "Installing Flask and gunicorn"
    pip3.6 install flask
    pip3.6 install gunicorn

    echo "To Run this app run the following command"
    echo "gunicorn helloworld:app"
    echo "Goto browser: http://<server_ip>"
    echo "You should see Hello World message"
    echo ""
    echo "Note:By default gunicorn will bind on port 8000 and nginx is setup to proxy that"
    echo "If you want to change the port, you'll also have to change that in nginx"
}

function install_nginx {
    worker=$1
    server="$hostname $ip $2"
    echo "========== Setting up Nginx ==========="
    echo "Installing epel-release to get nginx added to yum"
    $installer install epel-release
    echo "Installing latest-stable nginx version now"
    $installer install nginx

    echo "Writing nginx config file with worker:$worker server:$server" 
    echo "$NGINX_CONFIG" | sed "s/<server_name/${server}/" | sed "s/<worker_processes>/${worker}/" > /etc/nginx/nginx.conf

    echo "Enabling nginx to start at pre-boot"
    systemctl enable nginx
}

function setup_firewall {
    #help: https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-7
    echo "============== Setting Firewalld ============="
    $installer install firewalld

    echo "Allowing http permanently"
    firewall-cmd --zone=public --permanent --add-service=http

    echo "Allowing https permanently"
    firewall-cmd --zone=public --permanent --add-service=https

    echo "Allowing ssh permanently"
    firewall-cmd --zone=public --permanent --add-service=ssh

    systemctl enable firewalld
}

function setup_fail2ban {
    echo "============= Setting Fail2Ban rules =========="

    #https://hostpresto.com/community/tutorials/how-to-secure-nginx-using-fail2ban-on-centos-7/
    echo "installing fail2ban"
    $installer install fail2ban fail2ban-systemd
    systemctl enable fail2ban

    echo "Setting default and nginx jails"
    #must be the first one to setup custom/local rules
    set_default_jail

    #un-comment below to setup nginx_auth ban
    #ban_nginx_auth

    ban_nginx_noscript
    ban_nginx_badbots
    ban_nginx_nohome
    ban_nginx_proxy_attempt

    #restart the service
    echo "Enabling fail2ban"
    systemctl enable fail2ban
    echo "Starting fail2ban"
    systemctl start fail2ban
}

function setup_ssl {

    echo "Installing certbot-nginx"
    $installer install certbot-nginx

    certbot --nginx -d $1 -d www.${1}

    openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

    sed -i 's/#ssl_cert/ssl_dhparam \/etc\/ssl\/certs\/dhparam\.pem/g' /etc/nginx/nginx.conf;

    echo "Setting up crontab to renew certificates"
    crontab -l > tmp_cron

    echo "15 3 * * * /usr/bin/certbot renew --quiet" >> tmp_cron
    crontab tmp_cron
    rm tmp_cron

    echo "==== certificate has been setup ====="

}

if ask "Do you want to install python";then
    install_python
else
    echo "You have skipped to install python"
fi

if ask "Do you want to install nginx";then
    install_nginx $1 $2
else
    echo "You have skipped nginx installation"
fi

if ask "Do you want to setup firewalld for security";then
    setup_firewall
else
    echo "WARNING!!!! You have skipped firewalld settings"
fi

if ask "Do you want to setup extra security for your nginx/ssh";then
    setup_fail2ban
else
    echo "WARNING!!!! You have skipped to set extra security using fail2ban."
fi

if ask "Do you want to configure SSL using Let's Encrypt";then
    setup_ssl $1
else
    echo "WARNING!!!! You have skipped SSL configuration"
fi

echo "Your server has been setup and is ready to use. Enjoy!"
