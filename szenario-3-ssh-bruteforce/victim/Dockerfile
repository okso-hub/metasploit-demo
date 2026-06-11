FROM ubuntu:22.04

# SSH-Server + sudo (fuer die Post-Exploitation/Eskalation)
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server sudo \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/run/sshd \
 && ssh-keygen -A

# Absichtlich SCHWACHE Accounts (das ist der Sinn der Demo):
#   admin       -> in der sudo-Gruppe (Eskalation moeglich)
#   mitarbeiter -> normaler User
RUN useradd -m -s /bin/bash admin       && echo 'admin:password1'    | chpasswd && usermod -aG sudo admin \
 && useradd -m -s /bin/bash mitarbeiter && echo 'mitarbeiter:hallo123' | chpasswd

# Passwort-Login erlauben, root-Login sperren (realistisch)
RUN sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/'                /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
