FROM alpine:latest

RUN apk add --no-cache openssh-server rsyslog && \
    ssh-keygen -A && \
    adduser -D -s /bin/sh sshuser && \
    echo 'sshuser:password' | chpasswd && \
    echo 'root:rootpassword' | chpasswd && \
    mkdir -p /var/log && \
    touch /var/log/auth.log && \
    chmod 640 /var/log/auth.log && \
    mkdir -p /home/sshuser/.ssh && \
    chmod 700 /home/sshuser/.ssh

EXPOSE 2323

CMD rsyslogd && /usr/sbin/sshd -D -f /etc/ssh/sshd_config
