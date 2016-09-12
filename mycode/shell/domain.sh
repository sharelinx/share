#!/bin/bash
print_ok(){ 
   if [ $? -eq 0 ]
   then   
        echo -e "$1 \033[32m OK \033[0m" 
   else	
	    echo -e "$1 \033[31m Fail \033[0m"
		exit 1
   fi		
}
check_file(){
if [ ! -f "$1" ] 
then
   echo "$1 not exit" >> "$dir"/"$0"_file.log 
   exit 1
fi
 }
add_ng(){
    > /tmp/test.s
    > /tmp/test.assist
    for i in $slave
    do
	   check_file "/game/"$mysite"/nginx.combine."$i"_`date +%F`"
       grep "server_name" /game/"$mysite"/nginx.combine."$i"_`date +%F`|egrep -v "#|res|assist"   >> /tmp/test.s
	   print_ok "$i test.s"
	   grep "server_name" /game/"$mysite"/nginx.combine."$i"_`date +%F`|egrep  "assist"|grep -v "#"  >> /tmp/test.assist
	   print_ok "$i test.assist"
    done

    cat /tmp/test.s |grep -v "shenquol.com"|sort -k2 > /game/"$mysite"/nginx.combine.s."$mysite"_`date +%F`
    cat /tmp/test.assist|grep -v "shenquol.com" |sort -k2  > /game/"$mysite"/nginx.combine.assist."$mysite"_`date +%F`
	
    grep -of /tmp/test.s  /usr/local/nginx-1.0.5/vhosts/nginx."$serverdir".conf && grep -of /tmp/test.assist  /usr/local/nginx-1.0.5/vhosts/nginx."$serverdir".conf 

if [ $? -eq 0 ]
then
	    echo -e "\033[32m OK \033[0m ......slave DNS_info is already insert into the master nginx config file."
else
        check_file "/game/"$mysite"/nginx.combine.s."$mysite"_`date +%F`"
		check_file "/game/"$mysite"/nginx.combine.assist."$mysite"_`date +%F`"
        cp /usr/local/nginx-1.0.5/vhosts/nginx."$serverdir".conf{,`date +%F`}
		print_ok "back master conf"
	    line_s=`sed -n '/server_name s/=' /usr/local/nginx-1.0.5/vhosts/nginx.$serverdir.conf|tail -1`
        sed -i ''$line_s' r /game/'$mysite'/nginx.combine.s.'$mysite'_'`date +%F`'' /usr/local/nginx-1.0.5/vhosts/nginx."$serverdir".conf
		print_ok "insert server_name s"
		line_assist=`sed -n '/server_name assist/=' /usr/local/nginx-1.0.5/vhosts/nginx.$serverdir.conf|tail -1`
        sed -i ''$line_assist' r /game/'$mysite'/nginx.combine.assist.'$mysite'_'`date +%F`'' /usr/local/nginx-1.0.5/vhosts/nginx."$serverdir".conf
	    print_ok "insert server_name assist"
		/usr/local/nginx-1.0.5/sbin/nginx -s reload
		print_ok "nginx reload"
fi
}   

	
	
main(){
    dir=`cd $(dirname $0);pwd`
	cd $dir	
	touch domain.log
	:> domain.log
    check_file ""$dir"/config.deploy"
    mysite=`grep my_site "$dir"/config.deploy|awk -F::: '{gsub(/ /,"");print $2}'`
    slave=`grep "sites" "$dir"/config.deploy|awk -F::: '{gsub(/('$mysite'|,)/," ");print $2}'`
	serverdir=`awk -F/ '/^Path/ {print $3}' /game/"$mysite"/config.txt`
	gameName=`awk -F::: '/^joinContent:/{gsub(" ","");print $2}' "$dir"/config.deploy`
	rtxuser=`awk -F::: '/^current_task_user/{gsub(" ","");print $2}' "$dir"/config.deploy`
	create_user=`awk -F::: '/^create_task_user/{gsub(" ","");print $2}' "$dir"/config.deploy`
	
	
if [ `grep "BindDomain:::1" "$dir"/config.deploy` ]
then
    echo "-1" > "$dir"/check.deploy
    add_ng &> "$dir"/domain.log
	domainBind="`echo;awk '/server_name/{print $2}' /game/$mysite/nginx|sed 's/;\|res.*//g';echo "解析到";ifconfig eth0 |awk -F[:\ ]+ '/Bcast/{print "电信"$4}';ifconfig eth0:1 |awk -F[:\ ]+ '/Bcast/{print "联通"$4}'`"
    sqgame "$mysite" sendrtxmail "$rtxuser,$create_user" "神曲合区域名解析" "`echo ${gameName}"$domainBind"|sed ':label;N;s/\n/%0d/g;b label'`" 1 &> checkCombineDB.log
    echo "0" > "$dir"/check.deploy
else
    echo "0" > "$dir"/check.deploy
fi


}
main