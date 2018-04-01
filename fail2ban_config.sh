#Reference:
#https://www.digitalocean.com/community/tutorials/how-to-protect-ssh-with-fail2ban-on-centos-7
#https://www.digitalocean.com/community/tutorials/how-to-protect-an-nginx-server-with-fail2ban-on-ubuntu-14-04

function create_filter_conf {

    filename=$1
    content="$2"
    cwd=$(pwd)
    cd /etc/fail2ban/filter.d
    echo "$2" > "$1"
    cd $cwd

}

function set_default_jail {
    default=$(cat <<-EOF
    [DEFAULT]
    # Ban hosts for one hour:
    bantime = 3600

    # Override /etc/fail2ban/jail.d/00-firewalld.conf:
    #banaction = iptables-multiport
    banaction = firewallcmd-ipset

    [sshd]
    enabled = true
EOF
)
    echo "$default" > /etc/fail2ban/jail.local
}

function ban_nginx_auth {
    cfg=$(cat <<-EOF
    #To enable log monitoring for Nginx login attempts.
    #un-comment below section to add nginx authentication jail
    [nginx-auth]
    enabled = true
    filter = nginx-auth
    action = iptables-multiport[name=NoAuthFailures, port="http,https"]
    logpath = /var/log/nginx*/*error*.log
    bantime = 600 # 10 minutes
    maxretry = 6[nginx-login]
    enabled = true
    filter = nginx-login
    action = iptables-multiport[name=NoLoginFailures, port="http,https"]
    logpath = /var/log/nginx*/*access*.log
    bantime = 600 # 10 minutes
    maxretry = 6
EOF
)
    echo "$cfg" >> /etc/fail2ban/jail.local

    filter=$(cat <<EOF
[Definition]

failregex = ^ \[error\] \d+#\d+: \*\d+ user "\S+":? (password mismatch|was not found in ".*"), client: <HOST>, server: \S+, request: "\S+ \S+ HTTP/\d+\.\d+", host: "\S+"\s*$
            ^ \[error\] \d+#\d+: \*\d+ no user/password was provided for basic authentication, client: <HOST>, server: \S+, request: "\S+ \S+ HTTP/\d+\.\d+", host: "\S+"\s*$

ignoreregex =
EOF
)
    create_filter_conf "nginx-auth.conf" "$filter"
}

function ban_nginx_noscript {
    cfg=$(cat<<-EOF
    #You can create an [nginx-noscript] jail to ban clients that are searching for scripts on the website to execute and exploit. If you do not use PHP #or any other language in conjunction with your web server, you can add this jail to ban those who request these types of resources:
    #to ban clients that are searching for scripts on the website to execute and exploit.
    [nginx-noscript]
    enabled = true
    action = iptables-multiport[name=NoScript, port="http,https"]
    filter = nginx-noscript
    logpath = /var/log/nginx*/*access*.log
    maxretry = 6
    bantime  = 86400 # 1 day
EOF
)
    echo "$cfg" >> /etc/fail2ban/jail.local

    filter=$(cat <<EOF
[Definition]

failregex = ^<HOST> -.*GET.*(\.php|\.asp|\.exe|\.pl|\.cgi|\.scgi)

ignoreregex =
EOF
)
    create_filter_conf "nginx-noscript.conf" "$filter"
}

function ban_nginx_badbots {
    cfg=$(cat<<-EOF
    # to stop some known malicious bot request patterns
    [nginx-badbots]
    enabled  = true
    filter = apache-badbots
    action = iptables-multiport[name=BadBots, port="http,https"]
    logpath = /var/log/nginx*/*access*.log
    bantime = 86400 # 1 day
    maxretry = 1
EOF
)
    echo "$cfg" >> /etc/fail2ban/jail.local

    #we'll just copy over apache-badbots conf
    filter=$(cat /etc/fail2ban/filter.d/apache-badbots.conf)
    create_filter_conf "nginx-badbots.conf" "$filter"
}

function ban_nginx_nohome {
    cfg=$(cat<<-EOF
    #to provide access to web content within users' home directories
    [nginx-nohome]
    enabled  = true
    port     = http,https
    filter   = nginx-nohome
    logpath  = /var/log/nginx/access.log
    maxretry = 2
EOF
)
    echo "$cfg" >> /etc/fail2ban/jail.local

    filter=$(cat <<EOF
[Definition]

failregex = ^<HOST> -.*GET .*/~.*

ignoreregex =
EOF
)
    create_filter_conf "nginx-nohome.conf" "$filter"
}

function ban_nginx_proxy_attempt {

    cfg=$(cat<<-EOF
    #ban clients attempting to use our Nginx server as an open proxy
    [nginx-proxy]
    enabled = true
    action = iptables-multiport[name=NoProxy, port="http,https"]
    filter = nginx-proxy
    logpath = /var/log/nginx*/*access*.log
    maxretry = 0
    bantime  = 86400 # 1 day

EOF
)
    echo "$cfg" >> /etc/fail2ban/jail.local

    filter=$(cat <<EOF
[Definition]

failregex = ^<HOST> -.*GET http.*

ignoreregex =
EOF
)
	create_filter_conf "nginx-proxy.conf" "$filter"
}
