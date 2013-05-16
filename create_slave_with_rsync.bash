#!/bin/bash 
##This is meanst to be run on the slave, with the masters ip as the passed variable. ($1)
sourcehost="$1"
datadir=/var/lib/postgresql/9.2/main
archivedir=/var/lib/postgresql/9.2/archive
archivedirdest=/var/lib/postgresql/9.2/archive

#Usage
if [ "$1" = "" ] || [ "$1" = "-h" ] || [ "$1" = "-help" ] || [ "$1" = "--help" ] ;
then
	echo "Usage: $0 masters ip address"
	echo
exit 0
fi

Whoami () {
if [[ $(whoami) != "postgres" ]]
then
      echo "This script must be run as user Postgres, and passwordless ssh must already be setup"
      exit 1
fi
} 

CheckIfPostgresIsRunningOnRemoteHost () {
isrunning="$(ssh postgres@"$1" 'if killall -0 postgres; then echo "postgres_running"; else echo "postgress_not_running"; fi;')"

if [[ "$isrunning" = "postgress_not_running" ]]
then
        echo "postgres not running on the master, exiting";
        exit 1

elif [[ "$isrunning" = "postgres_running" ]]
then
        echo "postgres running on remote host";

elif echo "unexpected response, exiting"
then
        exit 1
fi
}

CheckIfMasterIsActuallyAMaster () {
ismaster="$(ssh postgres@"$1" 'if [ -f /var/lib/postgresql/9.2/main/recovery.done ]; then echo "postgres_is_a_master_instance"; else echo "postgres_is_not_master"; fi;')"

if [[ "$ismaster" = "postgres_is_not_master" ]]
then 
        echo "postgres is already running as a slave, exiting"; 
        exit 1

elif [[ "$ismaster" = "postgres_is_a_master_instance" ]]
then
       echo "postgres is running as master (probably)";

elif echo "unexpected response, exiting"
then
        exit 1

fi
}

echo "Sanity checks passed executing rest of script"
#prepare local server to become the new slave server. 
PrepareLocalServer () {

if [[ -f "/tmp/trigger_file" ]]
then
	rm /tmp/trigger_file
fi

bash /etc/init.d/postgresql stop

if [[ -f "$datadir/recovery.done" ]];
then
	mv "$datadir"/recovery.done "$datadir"/recovery.conf
fi
}


CheckForRecoveryConfig () {
if [[ -f "$datadir/recovery.conf" ]];
    then
	echo "Slave Config File Found, Continuing"
    else
	echo "Recovery.conf not found Postgres Cannot Become a Slave, Exiting"
	exit 1
fi
}


#put master into  backup mode
#TODO before doing PutMasterIntoBackupMode clean up archive logs (IE rm or mv /var/lib/postgresql/9.2/archive/*). They are not needed since we are effectivly createing a new base backup and then synching it. 
PutMasterIntoBackupMode () {
ssh postgres@"$1" "psql -c \"SELECT pg_start_backup('Streaming Replication', true)\" postgres"
}

#rsync masters data to local postgres dir
RsyncWhileLive () {
rsync -C -av --delete -e ssh --exclude recovery.conf --exclude recovery.done --exclude postmaster.pid  --exclude pg_xlog/ "$1":"$datadir"/ "$datadir"/
}


#this archives the the WAL log (ends writing to it and moves it to the $archive dir
StopBackupModeAndArchiveIntoWallLog () {
ssh postgres@"$1" "psql -c \"SELECT pg_stop_backup()\" postgres"
rsync -C -a -e ssh "$1":"$archivedir"/ "$archivedirdest"/
}


#stop postgres and copy transactions made during the last two rsync's
StopPostgreSqlAndFinishRsync () {
ssh postgres@"$1" "/etc/init.d/postgresql stop"
rsync -av --delete  -e ssh "$sourcehost":"$datadir"/pg_xlog/ "$datadir"/pg_xlog/
}

#Start both Master and Slave
StartLocalAndThenRemotePostGreSql () {
/etc/init.d/postgresql start
ssh postgres@"$1" "/etc/init.d/postgresql start"
}

#Execute above operations
Whoami
CheckIfPostgresIsRunningOnRemoteHost "$1"
CheckIfMasterIsActuallyAMaster "$1"
PrepareLocalServer "$datadir"
CheckForRecoveryConfig "$datadir"
PutMasterIntoBackupMode "$1"
RsyncWhileLive "$1"
StopBackupModeAndArchiveIntoWallLog "$1" "$archivedir" "$archivedirdest"
StopPostgreSqlAndFinishRsync "$1"
StartLocalAndThenRemotePostGreSql "$1"





