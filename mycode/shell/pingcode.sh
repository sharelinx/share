#!/bin/bash
###this script to test the domain name
##by lv.
Pin(){
if [ `cat test.txt |wc -l` == 0 ]
then
    echo -e "[\033[31m False  \033[0m] /root/test.txt is null"
else
  turn=0
  for p in `cat /root/test.txt`
  do
    dq=`echo $p |awk -F. '{print $1}'|sed 's/[a-z]//g'`
    ping -c2 $p &>/dev/null
    case $? in 
           0)
                  case $1 in 
                       1)        
                         echo -e "$name $dq ...... [\033[32m ok \033[0m]" ;;
                       *)
                         (( turn++ )) ;;
                   esac
              ;;
            *)
            echo -e "$name $dq ....... [\033[31m False \033[0m]"
              ;;
    esac
    if [ $turn = 3 ]
    then
       echo -e "$name $dq ...... [\033[32m ok \033[0m]"
       turn=0
    fi
  done
  echo -e "清空域名文件:         [\033[32m ok \033[0m] " 
  > /root/test.txt
fi
}
case $1 in
     qf)
       name="乔峰传"
       Pin $2
        ;;
     tk)
       name="九州天空城"
       Pin $2
        ;;
     sq)
       name="神曲"
       Pin $2
        ;;
     rh)
       name="符文"
       Pin $2
        ;;
     *)
echo -e "[\033[31m /root/test.txt \033[0m]  域名输入"
cat <<EOF
  参数： 
       qf  乔峰传
       tk  九州天空城
       sq  神曲
       rh  符文
EOF
echo
       ;;
esac