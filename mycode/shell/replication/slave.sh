#!/bin/bash
####this is for building slave script
##by lv.
ml="/tmp"
source $ml/config
###check ok
check(){
  if [ $? != 0 ]
  then
     echo "error,please check log."
     exit 1
  fi
}
##close seliux
syum(){
  if ! rpm -qa|grep -q $1
    then
      yum install -y $1
     check
  else
    echo "$1 is already installed"
fi
}
init(){
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
selinux_s=`getenforce`
if [ $selinux_s == "Enforcing"  -o $selinux_s == "enforcing" ]
then
    setenforce 0
fi
##close iptables
iptables-save > /etc/sysconfig/iptables_`date +%s`
iptables -F
service iptables save
yum install -y wget
##install the mirror.aliyun.com
cd /etc/yum.repos.d/
  if rpm -qa |grep epel-release >/dev/null
  then
    rpm -e epel-release
   fi
if [ -f epel.repo ]
then
  /bin/mv epel.repo epel.repo.bak
fi
  if [ -f CentOS-Base.repo ]
   then
    /bin/mv CentOS-Base.repo CentOS-Base.repo.bak
    wget -O /etc/yum.repos.d/CentOS-Base.repo $url_centos
     wget $url_epel -O /etc/yum.repos.d/epel.repo
  fi
yum clean all
yum makecache
#first to update datetime
[ `rpm -qa |grep ntpdate|wc -l` -eq 1 ] || yum install -y ntpdate
ntpdate 0.openwrt.pool.ntp.org 2>&1 >/dev/null;clock -w
## install some packges for the first on setup.
for p in gcc perl perl-devel libaio libaio-devel pcre-devel zlib-devel cmake glibc pcre compat-libstdc++-33
do
   syum $p
done
}


###check file is already in tmp
file_(){
if [ ! -f $ml/my.cnf ] && [ ! -f $ml/mysqld ] && [ ! -f $ml/mysql-* ] && [ ! -f $ml/slave.tmp ] && [ ! -f $ml/config]
then
   echo "file error,please try to sync again"
   exit 1
fi
mysql=`ls $ml |grep tar.gz`
version=`echo $ml/$mysql|awk -F - '{print $2}'|cut -d. -f2`

}

######install mysql
ins_mysql(){
cd $ml
tar -zxf $mysql
mv `echo $mysql|sed 's/.tar.gz//g'` /usr/local/mysql
cd /usr/local/mysql
if ! grep "^mysql:" /etc/passwd
then
   useradd -s /sbin/nologin -M mysql
   check
fi
[ -d /data/mysql ] && /bin/mv /data/mysql /data/mysql_`date +%s`
mkdir -p /data/mysql
chown -R mysql:mysql /data/mysql
###initialize
case $version in
      1)
    /usr/local/mysql/scripts/mysql_install_db --user=mysql --datadir=/data/mysql
     check
     sed -i '/^server-id/'d /tmp/my.cnf
     check
     sed -i '/\[mysqld\]/a\server-id=2' /tmp/my.cnf
     check
     ;;
     6)
     /usr/local/mysql/scripts/mysql_install_db --user=mysql --datadir=/data/mysql
      check
     sed -i '/^server_id/'d /tmp/my.cnf
     check
     sed -i '/\[mysqld\]/a\server_id = 2' /tmp/my.cnf
     check
      ;;
     7)
      pswd5_7=`/usr/local/mysql/bin/mysqld --user=mysql --datadir=/data/mysql --initialize 2>&1 |sed -r -n '/localhost: /p'|sed 's/.* //g'`
     /usr/local/mysql/bin/mysql_ssl_rsa_setup --datadir=/data/mysql
     check
     sed -i '/^server_id/'d /tmp/my.cnf
     check
     sed -i '/\[mysqld\]/a\server_id = 2' /tmp/my.cnf
     check
     ;;
  esac
###cp conf file
/bin/cp -rf /tmp/my.cnf /etc/my.cnf
check
/bin/cp -rf /tmp/mysqld /etc/init.d/
check
chmod 755 /etc/init.d/mysqld
chkconfig --add mysqld
chkconfig mysqld on
service mysqld start
check
####change mysql password
if [ $version -eq 7 ]
then
    /usr/local/mysql/bin/mysql -uroot -p$pswd5_7 --connect-expired-password -e "set password=password('$my_passwd');"
    check
else
   /usr/local/mysql/bin/mysql -uroot -e "set password=password('$my_passwd');"
   check
fi
}
sql_input(){
###input date
if [ -f /tmp/all.sql ]
then
   /usr/local/mysql/bin/mysql -uroot -p$my_passwd < /tmp/all.sql
   check
else
   echo "date error."
   exit 1
fi
}
slave_in(){
######binlog
slave_bin=`grep "mysql-bin" /tmp/slave.tmp`
slave_pos=`grep '^[0-9]' /tmp/slave.tmp`
###stop slave
/usr/local/mysql/bin/mysql -uroot -p$my_passwd -e "stop slave;"
check
###configure slave
/usr/local/mysql/bin/mysql -uroot -p$my_passwd -e "change master to master_host='$mas_ip',master_port=3306,master_user='$rp_user',master_password='$rp_passwd',master_log_file='$slave_bin',master_log_pos=$slave_pos;"
check
###start slave
/usr/local/mysql/bin/mysql -uroot -p$my_passwd -e "start slave;"
check
###check repecation status
show=`/usr/local/mysql/bin/mysql -uroot -p$my_passwd -e "show slave status\G;"|grep -A1 'Slave_IO_Running:'`
slaveIO=`echo $show|awk -F':' '{print $2}'`
Slave_SQL=`echo $show|awk -F':' '{print $2}'`

if [ $slaveIO == Yes ] && [$Slave_SQL == Yes ]
then
  echo "mysql repliation is start"
  /bin/rm -rf /tmp/all.sql /tmp/$mysql /tmp/mysqld /tmp/my.cnf /tmp/slave.tmp
  exit 0
else
  echo "error,please check the log."
  exit 1
fi
}
file_
if [ `ps aux|grep -c mysql` -gt 1 ]
then
   echo -e "\033[31m mysql is already start \033[0m"
   sql_input
   slave_in
else
   init
   ins_mysql
   sql_input
   slave_in
   check
fi 