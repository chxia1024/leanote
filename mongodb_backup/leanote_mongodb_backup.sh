source ~/chxia/env.sh

BACKUP_ROOT=/home/admin/chxia/sw/leanote_backup/
BACKUP_PREFIX=leanote_mongodb
MAX_BACKUPS=10

backup_checksum_exists()
{
    checksum=$1
    /bin/ls $BACKUP_ROOT | grep $checksum >/dev/null 2>&1
    return $?
}

save_backup()
{
    supply_backup_buffer $MAX_BACKUPS
    localfile=$1
    backup_checksum=$2
    upload=${BACKUP_ROOT}${BACKUP_PREFIX}_`date +%s`_${backup_checksum}.tar.gz
    /bin/cp $localfile $upload
    return $?
}

send_mail()
{
    status=$1
    msg=$2
    if [ $status -ne 0 ]; then
        /home/admin/chxia/tools/mail.py "[LeanoteBackup Failed]" "$msg"
    else
        /home/admin/chxia/tools/mail.py "[LeanoteBackup Successfully]" "$msg"
    fi
}

supply_backup_buffer()
{
    max=$MAX_BACKUPS
    pattern=$BACKUP_PREFIX
    root=$BACKUP_ROOT
    current=`/bin/ls $root | grep $pattern | wc -l`
    echo "current $current, buffer max $max"
    if [ $current -le $max ]; then
        return
    fi
    to_remove=`expr $current - $max`
    echo "to remove file " $to_remove $current $max
    /bin/ls $root | grep $pattern | awk '{print $NF}' | sort -u | head -n $to_remove | while read file
    do
        echo "will remove $file"
        /bin/rm $root/$file
    done

}

dir_checksum()
{
    find $1 -type f | xargs -i md5sum {} | awk '{print $1}' | md5sum | awk '{print $1}' 
}

backup()
{
    dump="leanotedump"
    /bin/rm -rf $dump
    mongodump -d leanote -o $dump
    if [ $? != 0 ]; then
        echo "mongodump error!!!" 
        send_mail 1 "MongoDump ERROR!"
        return
    fi
    checksum=`dir_checksum $dump`
    echo "checksum for dbdump is " $checksum
    if ! backup_checksum_exists $checksum; then
        echo "do a backup now"
        localfile="leanote_mongodb.tar.gz"
        rm $localfile -f; tar -zcf $localfile $dump
        size=`du -sh $localfile | awk '{print $1}'`
        if save_backup $localfile $checksum; then
            send_mail 0 "Checksum file in local dir: $checksum , size $size"
        else
            send_mail 1 "Failed to save backup in oss."
        fi
    else
        echo "backup already exists"
    fi
}

while true;
do 
    backup
    sleep 3600 
done
