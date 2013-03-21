Postgres-streaming-replication-script
=====================================

Usage
-----
	./create_slave_with_rsync.bash $master_ip

Requirments
-----------
	* A Recovery.conf (Or recovery.done) in the postgresql data directroy
	* An archive directory eg: /var/lib/postgresql/9.2/archive/
	* A Replication user  eg: /usr/bin/psql -c "CREATE ROLE $name REPLICATION LOGIN PASSWORD $password"
	* An entry for the replication user in ph_hba.conf (eg: host all $name 192.168.1.100/32 trust)
	* the postgresql-contrib-9.* package (Provides pg_archivecleanup)
	* A postgres server designated as master with these setting in postgresql.conf

		wal_level = hot_standby
		archive_mode = on
		archive_command = 'cp -i "%p" /var/lib/postgresql/9.2/archive/"%f" </dev/null' 


Example Recovery.conf
---------------------
	# If "recovery.conf" is present in the PostgreSQL data directory, it is
	# read on postmaster startup.  After successful recovery, it is renamed
	# to "recovery.done" to ensure that we do not accidentally re-enter
	# archive recovery or standby mode.
	#
	standby_mode = 'on'
	primary_conninfo = '$master_ip port=5432 user=$user password=$password'
	trigger_file = '/tmp/trigger_file'
	#Note about restorecommand: It can be an scp to the "other" machines archive dir, useful if the slave falls behind (beyond the px_log)
	#and needs access to older logs. (Alternativly you can write your pglogs to a shared space (eg: nfs) )
	restore_command = 'cp /var/lib/postgresql/9.2/archive/%f "%p"'
	archive_cleanup_command = '/usr/lib/postgresql/9.2/bin/pg_archivecleanup /var/lib/postgresql/9.2/archive/ %r'

