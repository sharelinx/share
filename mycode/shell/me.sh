#!/bin/bash
##Lv change it
echo "#####It will install lamp or lnmp.#######"
sleep 2
##get ip address
ip=`/sbin/ifconfig |grep -A1 'eth0'|sed -e '/inet addr:/!d;s/.*inet addr://g;s/ .*$//g'`
###cpu processor for make.
cpu_p=`grep processor /proc/cpuinfo | wc -l`

##check last command is OK or not.
check_ok() {
if [ $? != 0 ]
then
    echo "Error, Check the error log."
    exit 1
fi
}

##get the archive of the system,i686 or x86_64.
ar=`arch`

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

##if the packge installed ,then omit.
myum() {
if ! rpm -qa|grep -q "^$1"
then
    yum install -y $1
    check_ok
else
    echo $1 already installed.
fi
}

## install some packges for the first on setup.
for p in gcc wget perl perl-devel libaio libaio-devel pcre-devel zlib-devel cmake glibc pcre
do
    myum $p
done

##install epel.
if rpm -qa epel-release >/dev/null
then
    rpm -e epel-release
fi
if ls /etc/yum.repos.d/epel-6.repo* >/dev/null 2>&1
then
    rm -f /etc/yum.repos.d/epel-6.repo*
fi
wget -P /etc/yum.repos.d/ http://mirrors.aliyun.com/repo/epel-6.repo
###download address update.
mysql_5_1=http://mirrors.sohu.com/mysql/MySQL-5.1/mysql-5.1.73-linux-$ar-glibc23.tar.gz
mysql_5_6=http://mirrors.sohu.com/mysql/MySQL-5.6/mysql-5.6.29-linux-glibc2.5-$ar.tar.gz
mysql_5_7=http://mirrors.sohu.com/mysql/MySQL-5.7/mysql-5.7.12-linux-glibc2.5-$ar.tar.gz
apc_2_2=http://mirror.bit.edu.cn/apache/httpd/httpd-2.2.31.tar.gz
apc_2_4=http://mirrors.hust.edu.cn/apache/httpd/httpd-2.4.20.tar.gz
apr=http://mirrors.hust.edu.cn/apache/apr/apr-1.5.2.tar.gz
apr_util=http://mirrors.hust.edu.cn/apache/apr/apr-util-1.5.4.tar.gz
php_5_5=http://cn2.php.net/distributions/php-5.5.34.tar.gz
php_5_6=http://hk2.php.net/distributions/php-5.6.20.tar.gz
php_7_0=http://cn2.php.net/distributions/php-7.0.5.tar.gz
ng=http://nginx.org/download/nginx-1.8.1.tar.gz

###lnmp config download###
nginx_conf=http://xz.lives90.cn/.nginx_conf
nginx_init=http://xz.lives90.cn/.nginx_init
php_conf=http://xz.lives90.cn/.php_conf

###fix the Cannot find libmysqlclient
php_fix="with-mysql=/usr/local/mysql"
php_sock="--with-mysql-sock=/tmp/mysql.sock"

##function of installing mysqld.
mysql_configure() {
     if ! grep '^mysql:' /etc/passwd
            then
                useradd -M mysql -s /sbin/nologin
                check_ok
            fi
            myum compat-libstdc++-33
            [ -d /data/mysql ] && /bin/mv /data/mysql /data/mysql_`date +%s`
            mkdir -p /data/mysql
            chown -R mysql:mysql /data/mysql
            cd /usr/local/mysql
            ./scripts/mysql_install_db --user=mysql --datadir=/data/mysql
            check_ok
	if [ -f  /usr/local/mysql/support-files/my-huge.cnf ]
         then
	     /bin/cp support-files/my-huge.cnf /etc/my.cnf
         else
            /bin/cp support-files/my-default.cnf /etc/my.cnf
        fi
            check_ok
            sed -i '/^\[mysqld\]$/a\datadir = /data/mysql' /etc/my.cnf
            /bin/cp support-files/mysql.server /etc/init.d/mysqld
            sed -i 's#^datadir=#datadir=/data/mysql#' /etc/init.d/mysqld
            chmod 755 /etc/init.d/mysqld
            chkconfig --add mysqld
            chkconfig mysqld on
            service mysqld start
            check_ok
}
mysql5_7_conf() {
            if ! grep '^mysql:' /etc/passwd
            then
                useradd -M mysql -s /sbin/nologin
            fi
            myum compat-libstdc++-33
            [ -d /data/mysql ] && /bin/mv /data/mysql /data/mysql_bak
            mkdir -p /data/mysql
            chown -R mysql:mysql /data/mysql
            cd /usr/local/mysql
            pswd5_7=`./bin/mysqld --user=mysql --datadir=/data/mysql --initialize 2>&1 |sed -r -n '/localhost: /p'|sed 's/.* //g'`
            check_ok
	    ./bin/mysql_ssl_rsa_setup --datadir=/data/mysql
	    check_ok
            /bin/cp support-files/my-default.cnf /etc/my.cnf
            check_ok
            sed -i '/^\[mysqld\]$/a\socket = /tmp/mysql.sock' /etc/my.cnf
	    sed -i '/^\[mysqld\]$/a\port = 3306' /etc/my.cnf
  	    sed -i '/^\[mysqld\]$/a\datadir = /data/mysql' /etc/my.cnf
	    sed -i '/^\[mysqld\]$/a\basedir = /usr/local/mysql' /etc/my.cnf
            /bin/cp support-files/mysql.server /etc/init.d/mysqld
            sed -i 's#^datadir=#datadir=/data/mysql#' /etc/init.d/mysqld
	    sed -i 's#^basedir=#basedir=/usr/local/mysql#' /etc/init.d/mysqld
            chmod 755 /etc/init.d/mysqld
            chkconfig --add mysqld
            chkconfig mysqld on
            service mysqld start
            check_ok
	    php_fix=`echo $php_fix |sed 's#with-mysql=/usr/local/mysql#with-mysql#g'`
	    check_ok
}

install_mysqld() {
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
            mysql_configure
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
            mysql_configure
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
            mysql5_7_conf
            break
            ;;
	*)
            echo "only 1(5.1) 2(5.6) or 3(5.7) "
            exit 1
            ;;
    esac
done
}

##function of install httpd.
install_httpd() {
echo "Chose the version of Apache."
select apc_v in 2.2 2.4
do
    case $apc_v in
        2.2)
          cd /usr/local/src
         for apr in apr apr-devel
 	  do
   		myum $apr
          done
	[ -f ${apc_2_2##*/}  ] || wget $apc_2_2
	tar zxf  ${apc_2_2##*/}
	cd `echo ${apc_2_2##*/}|sed 's/.tar.gz//g'`
        check_ok
        ./configure \
        --prefix=/usr/local/apache2 \
        --with-included-apr \
        --enable-so \
        --enable-deflate=shared \
        --enable-expires=shared \
        --enable-rewrite=shared \
        --with-pcre
        check_ok
        make -j $cpu_p
	check_ok
        make install
        check_ok
	break
	;;
	2.4)
        cd /usr/local/src
####apr install
	[ -f ${apr##*/} ] || wget $apr
	tar zxf ${apr##*/}
	check_ok
	if [ -d /usr/local/apr ] 
	then
        /bin/mv /usr/local/apr /usr/local/apr_`date +%s`
	fi
	check_ok
	cd `echo ${apr##*/}|sed 's/.tar.gz//g'`
	sed -i 's#$RM "$cfgfile"##g' ./configure
	./configure  --prefix=/usr/local/apr
	check_ok
	make -j $cpu_p
	check_ok 
        make install
	check_ok
####apr_util install
	[ -f ${apr_util##*/} ] || wget $apr_util
	tar zxf ${apr_util##*/}
        check_ok
	if [ -d /usr/local/apr-util ]
	then
	/bin/mv /usr/local/apr-util /usr/local/apr_util_`date +%s`
	fi
	check_ok
	cd `echo ${apr_util##*/}|sed 's/.tar.gz//g'`
	./configure\
        --prefix=/usr/local/apr-util \
        --with-apr=/usr/local/apr/bin/apr-1-config
	check_ok
	make -j $cpu_p
        check_ok
 	make install
	check_ok
####Apache2.4 install
	[ -f ${apc_2_4##*/} ] || wget $apc_2_4
	tar zxf ${apc_2_4##*/}
        check_ok
	cd `echo ${apc_2_4##*/}|sed 's/.tar.gz//g'`
	./configure \
        --prefix=/usr/local/apache2 \
        --enable-so \
        --enable-deflate=shared \
        --enable-expires=shared \
        --enable-rewrite=shared \
        --with-pcre \
        --with-apr=/usr/local/apr \
        --with-apr-util=/usr/local/apr-util/
        check_ok
        make -j $cpu_p
        check_ok
	make install
        check_ok
	break
	;;
	*)
     echo "only 1(2.2) or 2(2.4)"
            exit 1
            ;;
    esac
done
}

##function of install lamp's php.
lamp_php() {
	for p in libxml2-devel openssl openssl-devel\
        bzip2 bzip2-devel libpng libpng-devel freetype-devel\
        libmcrypt-devel libjpeg-devel curl-devel
            do
                myum $p
            done
            check_ok
            ./configure \
            --prefix=/usr/local/php \
            --with-apxs2=/usr/local/apache2/bin/apxs \
            --with-config-file-path=/usr/local/php/etc  \
            --$php_fix \
            --with-libxml-dir \
            --with-gd \
            --with-jpeg-dir \
            --with-png-dir \
            --with-freetype-dir \
            --with-iconv-dir \
            --with-zlib-dir \
            --with-bz2 \
            --with-openssl \
            --with-mcrypt \
            --enable-soap \
            --enable-gd-native-ttf \
            --enable-mbstring \
            --enable-sockets \
            --enable-exif \
            --disable-ipv6
            check_ok
            make -j $cpu_p
            check_ok 
	    make install
            check_ok
            [ -f /usr/local/php/etc/php.ini ] || /bin/cp php.ini-production  /usr/local/php/etc/php.ini

}

install_php() {
echo -e "Install php.\nPlease chose the version of php."
select php_v in 5.5 5.6 7.0
do
    case $php_v in
        5.5)
            cd /usr/local/src/
            [ -f ${php_5_5##*/} ] || wget $php_5_5
            tar zxf ${php_5_5##*/} && cd `echo ${php_5_5##*/}|sed 's/.tar.gz//g'`
            lamp_php
	    break
            ;;
	5.6)
            cd /usr/local/src/
            [ -f ${php_5_6##*/} ] || wget $php_5_6
            tar zxf ${php_5_6##*/} &&   cd `echo ${php_5_6##*/}|sed 's/.tar.gz//g'`
            lamp_php
            break
            ;;
	7.0)
 	    cd /usr/local/src/
            [ -f ${php_7_0##*/} ] || wget $php_7_0
            tar zxf ${php_7_0##*/} &&   cd `echo ${php_7_0##*/}|sed 's/.tar.gz//g'`
	php_fix="with-mysqli"
            lamp_php
            break
            ;;
	*)
            echo "only 1(5.5) 2(5.6) 3(7.0)"
            ;;
    esac
done
}

##function of apache and php configue.
join_apa_php() {
sed -i '/AddType .*.gz .tgz$/a\AddType application\/x-httpd-php .php' /usr/local/apache2/conf/httpd.conf
check_ok
sed -i 's/DirectoryIndex index.html/DirectoryIndex index.php index.html index.htm/' /usr/local/apache2/conf/httpd.conf
check_ok
cat > /usr/local/apache2/htdocs/index.php <<EOF
<?php
   phpinfo();
?>
EOF

if /usr/local/php/bin/php -i |grep -iq 'date.timezone => no value'
then
    sed -i '/;date.timezone =$/a\date.timezone = "Asia\/Chongqing"'  /usr/local/php/etc/php.ini
fi
###fix ServerName error
grep 'ServerName localhost:80' /usr/local/apache2/conf/httpd.conf >/dev/null ||sed -i '/\#ServerName/a\ServerName localhost:80' /usr/local/apache2/conf/httpd.conf
check_ok
###fix ServerName error
/usr/local/apache2/bin/apachectl restart
check_ok
}

##function of check service is running or not, example nginx, httpd, php-fpm.
check_service() {
if [ "$1" == "phpfpm" ]
then
    s="php-fpm"
else
    s=$1
fi
n=`ps aux |grep "$s"|wc -l`
if [ $n -gt 1 ]
then
    echo "$1 service is already started."
else
    if [ -f /etc/init.d/$1 ]
    then
        /etc/init.d/$1 start
        check_ok
    else
        install_$1
    fi
fi
}

##function of install lamp
lamp() {
check_service mysqld
check_service httpd
install_php
join_apa_php
echo "LAMP done，Please use 'http://$ip/index.php' to access."
echo "IF use mysql5.7 this is the password: $pswd5_7"
}

##function of install nginx
install_nginx() {
cd /usr/local/src
[ -f ${ng##*/} ] || wget $ng
tar zxf ${ng##*/}
cd `echo ${ng##*/}|sed 's/.tar.gz//g'`
myum pcre-devel
./configure \
--prefix=/usr/local/nginx \
--with-http_realip_module \
--with-http_sub_module \
--with-http_gzip_static_module \
--with-http_stub_status_module \
--with-pcre

check_ok
make -j $cpu_p
check_ok
make install
check_ok
if [ -f /etc/init.d/nginx ]
then
    /bin/mv /etc/init.d/nginx  /etc/init.d/nginx_`date +%s`
fi
wget $nginx_init  -O /etc/init.d/nginx
check_ok
chmod 755 /etc/init.d/nginx
chkconfig --add nginx
chkconfig nginx on
wget $nginx_conf  -O /usr/local/nginx/conf/nginx.conf
check_ok
service nginx start
check_ok
echo -e "<?php\n    phpinfo();\n?>" > /usr/local/nginx/html/index.php
check_ok
}

##function of install php-fpm
lnmp_php(){
	for p in libxml2-devel openssl openssl-devel\
        bzip2 bzip2-devel libpng libpng-devel freetype-devel\
        libmcrypt-devel libjpeg-devel libcurl-devel libtool-ltdl-devel
        do
                myum $p
        done
            if ! grep -q '^php-fpm:' /etc/passwd
            then
                useradd -M -s /sbin/nologin php-fpm
                check_ok
            fi
	   ./configure \
           --prefix=/usr/local/php-fpm \
           --with-config-file-path=/usr/local/php-fpm/etc \
           --enable-fpm \
           --with-fpm-user=php-fpm \
           --with-fpm-group=php-fpm \
           --$php_fix \
           $php_sock \
           --with-libxml-dir \
           --with-gd \
           --with-jpeg-dir \
           --with-png-dir \
           --with-freetype-dir \
           --with-iconv-dir \
           --with-zlib-dir \
           --with-mcrypt \
           --with-pear \
           --with-curl \
           --with-openssl \
           --enable-soap \
           --enable-gd-native-ttf \
           --enable-ftp \
           --enable-mbstring \
           --enable-exif \
           --enable-zend-multibyte \
           --disable-ipv6
            check_ok
            make -j $cpu_p
            check_ok
	    make install
            check_ok
           [ -f /usr/local/php-fpm/etc/php.ini ] || /bin/cp php.ini-production  /usr/local/php-fpm/etc/php.ini
            if /usr/local/php-fpm/bin/php -i |grep -iq 'date.timezone => no value'
            then
                sed -i '/;date.timezone =$/a\date.timezone = "Asia\/Chongqing"'  /usr/local/php-fpm/etc/php.ini
                check_ok
            fi
            [ -f /usr/local/php-fpm/etc/php-fpm.conf ] || wget $php_conf -O /usr/local/php-fpm/etc/php-fpm.conf
		check_ok
            [ -f /etc/init.d/phpfpm ] || /bin/cp sapi/fpm/init.d.php-fpm /etc/init.d/phpfpm
            chmod 755 /etc/init.d/phpfpm
            chkconfig --add phpfpm
            chkconfig phpfpm on
            service phpfpm start
            check_ok
}
install_phpfpm() {
echo -e "Install php.\nPlease chose the version of php."
select php_v in 5.5 5.6 7.0
do
    case $php_v in
	5.5)
            cd /usr/local/src/
            [ -f ${php_5_5##*/} ] || wget $php_5_5
            tar zxf ${php_5_5##*/} && cd `echo ${php_5_5##*/}|sed 's/.tar.gz//g'`
            lnmp_php
            break
            ;;
	5.6)
            cd /usr/local/src/
            [ -f ${php_5_6##*/} ] || wget $php_5_6
            tar zxf ${php_5_6##*/} &&   cd `echo ${php_5_6##*/}|sed 's/.tar.gz//g'`
            lnmp_php
            break
            ;;
	7.0)
	cd /usr/local/src/
            [ -f ${php_7_0##*/} ] || wget $php_7_0
            tar zxf ${php_7_0##*/} &&   cd `echo ${php_7_0##*/}|sed 's/.tar.gz//g'`
	   php_fix="with-mysqli"
	   php_sock=`echo $php_sock| sed 's#--with-mysql-sock=/tmp/mysql.sock##g'`
            lnmp_php
            break
            ;;
	*)
            echo 'only 1(5.5)  2(5.6) or 3(7.0)'
            ;;
    esac
done
}

##function of install lnmp
lnmp() {
check_service mysqld
check_service nginx
check_service phpfpm
echo "The lnmp done, Please use 'http://$ip/index.php' to access."
echo "IF use mysql5.7 this is the password: $pswd5_7"
}

###input control
while :
do
read -p "Please chose which type env you install, (lamp|lnmp)? " t
  if [ "$t" == "lamp" -o "$t" == "lnmp" ]
   then
   case $t in
    lamp)
        lamp
        ;;
    lnmp)
        lnmp
        ;;
    *)
        echo "Only 'lamp' or 'lnmp' your can input."
        ;;
   esac
 break
else
  echo "Only 'lamp' or 'lnmp' your can input,please retry. "
fi
done
