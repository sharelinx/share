#!/bin/bash
##this is a shell script to use install samba server
###by lv.
echo "#######samba server will be install now ########"
sleep 3
##check the last command is ok
check(){
if [ $? != 0 ]
then
   echo "error,Check the error log."
    exit 1
fi
}
###close selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
selinux_s=`getenforce`
if [ $selinux_s == "Enforcing"  -o $selinux_s == "enforcing" ]
then
    setenforce 0
fi
####input the port in iptables
/sbin/iptables -I INPUT -p tcp --dport 445 -j ACCEPT
/sbin/iptables -I INPUT -p tcp --dport 139 -j ACCEPT
/sbin/iptables -I OUTPUT -p tcp --sport 445 -j ACCEPT
/sbin/iptables -I OUTPUT -p tcp --sport 139 -j ACCEPT
service iptables save
####yum install samba server
yum install -y samba samba-client
check
###create samba user
   read -p "input sambe username: " user
   /usr/sbin/useradd -s /sbin/nologin $user -M
   echo "input sambe password"
   pdbedit -a $user
###configure the conf file
cat >>/etc/samba/smb.conf <<EOF
[server]
   comment = samba server
   path = /home/$user
   browseable = yes
   public = yes
   writable = yes
EOF
sed -i 's#workgroup = MYGROUP#workgroup = WORKGROUP#g' /etc/samba/smb.conf
check
/etc/init.d/smb start
check
exit 0