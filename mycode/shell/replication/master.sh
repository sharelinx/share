#!/bin/bash
#####this is building mysql replication###
##by lv.
ml=`pwd`
ar=`arch`
source $ml/config

###check ok
check(){
  if [ $? != 0 ]
  then
     echo "error,please check log."
     exit 1
  fi
}
file_(){
####check the file is exist
for wj in $ml/cp_slave.expect $ml/ins_rsync.expect $ml/slave.expect $ml/slave.sh $ml/config
do
   if [ ! -f $wj ]
   then
    echo "error,your miss $wj file."
    exit 1
   else
     /bin/chmod +x $wj
     check
   fi
done
echo "1:File install:ok" >> /tmp/list
}

##install the mirror.aliyun.com
aliyun(){
cd /etc/yum.repos.d/
  if rpm -qa |grep epel-release >/dev/null
  then
    rpm -e epel-release
   fi
if [ -f epel.repo ]
then
  /bin/mv epel.repo epel.repo.bak
fi
  yum install -y wget
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
}

###install lib software
syum(){
  if ! rpm -qa|grep -q $1
    then
      yum install -y $1
     check
  else
    echo "$1 is already installed"  
fi
}
## install some packges for the first on setup.
init(){
##close seliux
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
if [ `grep -c $yun /etc/yum.repos.d/CentOS-Base.repo` -eq 0 ]
then
    aliyun
else
   echo "aliyun epel is already installed."
fi 

for p in gcc perl perl-devel libaio libaio-devel pcre-devel zlib-devel cmake glibc pcre compat-libstdc++-33 rsync expect vim-enhanced
do
   syum $p
done
echo "2:init:ok" >> /tmp/list
}
#######################################
conf_mysql(){
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
      5.1)
    ./scripts/mysql_install_db --user=mysql --datadir=/data/mysql
     check
     ;;
     5.6)
     ./scripts/mysql_install_db --user=mysql --datadir=/data/mysql
      check
      ;;
     5.7)
      pswd5_7=`./bin/mysqld --user=mysql --datadir=/data/mysql --initialize 2>&1 |sed -r -n '/localhost: /p'|sed 's/.* //g'`
     ./bin/mysql_ssl_rsa_setup --datadir=/data/mysql
     check
     ;;
  esac
}
cp_mysql(){
###my.cnf
      if [ -f  /usr/local/mysql/support-files/my-huge.cnf ]
         then
         /bin/cp -rf support-files/my-huge.cnf /etc/my.cnf
         check
	 sed -i '/^\[mysqld\]$/a\datadir = /data/mysql' /etc/my.cnf
           check
         else
            /bin/cp -rf support-files/my-default.cnf /etc/my.cnf
             check
        sed -i '/^\[mysqld\]$/a\socket = /tmp/mysql.sock' /etc/my.cnf
        sed -i '/^\[mysqld\]$/a\port = 3306' /etc/my.cnf
        sed -i '/^\[mysqld\]$/a\datadir = /data/mysql' /etc/my.cnf
        check
        sed -i '/^\[mysqld\]$/a\basedir = /usr/local/mysql' /etc/my.cnf
        fi
####/etc/init.d/mysqld
     if [ $version == 5.7 ]
     then
      /bin/cp support-files/mysql.server /etc/init.d/mysqld
      check
       sed -i 's#^datadir=#datadir=/data/mysql#' /etc/init.d/mysqld
       sed -i 's#^basedir=#basedir=/usr/local/mysql#' /etc/init.d/mysqld
     check
      chmod 755 /etc/init.d/mysqld
      chkconfig --add mysqld
      chkconfig mysqld on
      service mysqld start
      check
     else
      /bin/cp support-files/mysql.server /etc/init.d/mysqld
      sed -i 's#^datadir=#datadir=/data/mysql#' /etc/init.d/mysqld
      chmod 755 /etc/init.d/mysqld
      chkconfig --add mysqld
      chkconfig mysqld on
      service mysqld start
      check
    fi

}

###install mysql
insall_mysql(){ 
echo "Chose the version of mysql."
select mysql_v in 5.1 5.6 5.7
do
    case $mysql_v in
        5.1)
            cd /usr/local/src
            [ -f ${mysql_5_1##*/} ] || wget $mysql_5_1
            tar zxf ${mysql_5_1##*/}
            check_ok
            [ -d /usr/local/mysql ] && /bin/mv /usr/local/mysql /usr/local/mysql_`date +%s`
            mv `echo ${mysql_5_1##*/}|sed 's/.tar.gz//g'` /usr/local/mysql
            check_ok
           version=5.1
            conf_mysql
            cp_mysql
        break
        ;;
    5.6)
            cd /usr/local/src
            [ -f ${mysql_5_6##*/} ] || wget $mysql_5_6
            tar zxf ${mysql_5_6##*/}
            check_ok
            [ -d /usr/local/mysql ] && /bin/mv /usr/local/mysql /usr/local/mysql_bak
            mv `echo ${mysql_5_6##*/}|sed 's/.tar.gz//g'` /usr/local/mysql
        check_ok
            version=5.6
            conf_mysql
            cp_mysql
        break
        ;;
    5.7)
            cd /usr/local/src
            [ -f ${mysql_5_7##*/} ] || wget $mysql_5_7
            tar zxf ${mysql_5_7##*/}
            check_ok
            [ -d /usr/local/mysql ] && /bin/mv /usr/local/mysql /usr/local/mysql_bak
            mv `echo ${mysql_5_7##*/}|sed 's/.tar.gz//g'` /usr/local/mysql
            check_ok
            version=5.7
           conf_mysql
           cp_mysql
            break
            ;;
    *)
            echo "only 1(5.1) 2(5.6) or 3(5.7) "
            exit 1
            ;;
    esac
done
}
####change mysql password
passwd_mysql(){
if [ $version == 5.7 ]
then
    /usr/local/mysql/bin/mysql -uroot -p$pswd5_7 --connect-expired-password -e "set password=password('$my_passwd');"
    check
else
   /usr/local/mysql/bin/mysql -uroot -e "set password=password('$my_passwd');"
   check
fi
if [ `ps aux|grep -c mysql` -gt 1 ]
then
   echo "3:mysql install:ok" >> /tmp/list
else
   echo "3:mysql install:fail" >> /tmp/list
fi
}
####start install slave
slave(){

echo "#############################"
echo "##                         ##"
echo "##      slave install      ##"
echo "##                         ##"
echo "#############################"
###replication building for master first
if [ `ps aux|grep mysql|wc -l` -gt 1 ] && [ `grep "log_bin = mysql-bin" /etc/my.cnf|wc -l` -eq 0 ] && [ `grep "log-bin=mysql-bin" /etc/my.cnf|wc -l` -eq 0 ]
then
   /etc/init.d/mysqld stop
   check
   sed -i '/^\[mysqld\]$/a\server_id = 1' /etc/my.cnf
   sed -i '/^\[mysqld\]$/a\log_bin = mysql-bin' /etc/my.cnf
   sed -i '/^\[mysqld\]$/a\binlog_format = "MIXED"' /etc/my.cnf
    check
   /etc/init.d/mysqld start
   check
fi
master_bin=`/usr/local/mysql/bin/mysql -uroot -p$my_passwd -e "show master status \G;"|grep File|awk '{print $2}'`
master_pos=`/usr/local/mysql/bin/mysql -uroot -p$my_passwd -e "show master status \G;"|grep Position|awk '{print $2}'`
echo $master_bin > /tmp/slave.tmp
echo $master_pos >>/tmp/slave.tmp
/usr/local/mysql/bin/mysql -uroot -p$my_passwd -e "grant replication slave on *.* to $rp_user@'$s_host' identified by '$rp_passwd';"
check
/usr/local/mysql/bin/mysql -uroot -p$my_passwd -e "flush privileges;"
check
###dump date
/usr/local/mysql/bin/mysqldump -uroot -p$my_passwd --single-transaction -A > /tmp/all.sql
check
}
sync_(){
  slave
####cp file to slave
if [ `pwd` != $ml ]
then
   cd $ml
fi
./ins_rsync.expect $s_user $s_host $s_passwd
for file in /usr/local/src/mysql-* /etc/my.cnf /etc/init.d/mysqld ./slave.sh /tmp/slave.tmp /tmp/all.sql ./config
do
   ./cp_slave.expect $s_user $s_host $s_passwd $file
   if [ $? == 0 ]
   then
      echo "$file is sync ok" >> /tmp/list
   else 
      echo "$file sync Fail"
   fi
done
if grep -c "Fail" /tmp/list &>/dev/null
then
   exit 1
else
   echo "4:slave sync:ok" >> /tmp/list
fi
}
slave_log(){
  if grep -c "4:slave sync:ok" /tmp/list &>/dev/null
  then
    ./slave.expect $s_host $s_passwd /tmp/slave.sh &> /tmp/slave.log
   fi
  if grep -c "error,please check log." /tmp/slave.log &>/dev/null
  then
     echo "5:slave install:Fail" >>/tmp/list
  else
     echo "5:slave install:ok" >>/tmp/list
  fi
} 
######
file_
if  grep -c "5:slave install:ok" /tmp/list &>/dev/null
then
    echo "The slave is Finish,don't running this script again"
	exit 1
elif grep -c "4:slave sync:ok" /tmp/list &>/dev/null
then
    slave_log
elif grep -c "3:mysql install:ok" /tmp/list &>/dev/null
then
   sync_
   slave_log
else
   init
   insall_mysql
   passwd_mysql
   sync_
   slave_log
   > /tmp/list
fi 

exit 0