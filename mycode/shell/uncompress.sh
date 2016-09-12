for a in `ls`
do
     case ${a##*.} in
        zip)
         unzip $a >/tmp/ffmpeg_log/uzip_$a.log
          ;;
        bz2)
         tar -jxf $a  >/tmp/ffmpeg_log/bz2_$a.log
          ;;
        xz)
          tar -Jxf $a >/tmp/ffmpeg_log/xz_$a.log
           ;;
        gz)
         tar -zxf $a >/tmp/ffmpeg_log/gz_$a.log
           ;;
         *)
          echo "$a is not a compress files"  >/tmp/ffmpeg_log/$a.log
       esac
done