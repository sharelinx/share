#!/bin/bash
source /etc/profile
for i in `showsite.sh |egrep -o "server|server1"`
do
 ln -s /usr/local/nginx-1.0.5/vhosts/nginx.$i.conf /game/$i/nginx &> /dev/null
done
