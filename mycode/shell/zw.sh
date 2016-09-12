#!/bin/bash
read -p "please input the ip address: " n
#####子网计算
zw=`echo $n|awk -F/ '{print $2}'`
ys=$[zw%8]
zws(){
di=255
d=128
host=$ys
tmp=$di
for (( i=$host;i>=1;i-- ))
do
      tmp=$[tmp ^ d]
      d=$[d >> 1]
done
jg=$[di ^ tmp]
}
if [ $ys -eq 0 ]
then
  cs=$[zw/8]
  case $cs in
     0)
      zwym=0.0.0.0
        ;;
     1)
      zwym=255.0.0.0
      ;;
     2)
      zwym=255.255.0.0
       ;;
     3)
      zwym=255.255.255.0
       ;;
     4)
      zwym=255.255.255.255
      ;;
     *)
     echo "you can see this ? oh my god. "
   esac
elif [ $zw -gt 0 ] && [ $zw -lt 8 ]
then
    zws
    zwym=$jg.0.0.0
elif [ $zw -gt 8 ] && [ $zw -lt 16 ]
then
   zws
   zwym=255.$jg.0.0   
elif [ $zw -gt 16 ] && [ $zw -lt 24 ]
then
   zws
   zwym=255.255.$jg.0
else
   zws
   zwym=255.255.255.$jg
fi
echo "子网掩码：$zwym"
###主机数计算
zjzs=$[32-zw]
sjzj=$[$[2**zjzs]-2]
echo "主机数为：$sjzj"
####子网数
zwzs=$[2**$[32-zw]]
echo "子网数：$zwzs"
####子网第一个网络地址
ip1=`echo $n|awk -F. '{print $1}'`
ip2=`echo $n|awk -F. '{print $2}'`
ip3=`echo $n|awk -F. '{print $3}'`
ip4=`echo $n|cut -d/ -f1|awk -F. '{print $4}'`
wl=`echo $zwym|tr '.' '\n'|grep 255|wc -l`
case $wl in
     0)
      wldz=0.0.0.0
        ;;
     1)
      wldz=$ip1.0.0.0
      ;;
     2)
      wldz=$ip1.$ip2.0.0
       ;;
     3)
      wldz=$ip1.$ip2.$ip3.0
       ;;
     *)
     echo "isn't have the wldz "
   esac
echo "子网网络地址：$wldz"
###第一个可用地址
echo "第一个可用地址：${wldz%.*}.1"
###块大小
zws
kuai=$[256-jg]
echo "每个子网的块大小：$kuai"
###广播地址
gbw=$[255 ^ jg]
case $wl in
     0)
      gb=$[ip1|gbw].255.255.255
        ;;
     1)
      gb=$ip1.$[ip2|gbw].255.255
      ;;
     2)
      gb=$ip1.$ip2.$[ip3|gbw].255
       ;;
     3)
      gb=$ip1.$ip2.$ip3.$[ip4|gbw]
       ;;
     *)
     echo "isn't have the wldz "
   esac
echo "广播地址为：$gb"
###最后一个可用地址
case $wl in
     0)
      zhdz=$[ip1|gbw].255.255.254
        ;;
     1)
      zhdz=$ip1.$[ip2|gbw].255.254
      ;;
     2)
      zhdz=$ip1.$ip2.$[ip3|gbw].254
       ;;
     3)
      zhdz=$ip1.$ip2.$ip3.$[$[ip4|gbw]-1]
       ;;
     *)
     echo "isn't have the wldz "
   esac
echo "最后一个可用地址为：$zhdz"