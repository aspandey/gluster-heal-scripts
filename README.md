# gluster-heal-scripts
Scripts to correct extended attributes of fragments of files to make them healable.

Following are the guidelines/suggestions to use these scripts.

1 - Passwordless ssh should be setup for all the nodes of the cluster.

2 - Scripts should be executed from one of these nodes.

3 - Make sure NO "IO" is going on for the files for which we are making changes
in extended attributes using correct_pending_heals.sh.

4 - There should be no heal going on for the file for which xattrs are being
set by correct_pending_heals.sh. Disable the self heal while running this script.

5 - All the bricks of the volume should be UP to identify good and bad fragments
and to decide if an entry is healable or not.

6 - If correct_pending_heals.sh is stopped in the middle while it was processing
healable entries, it is suggested to re-run gfid_needing_heal_parallel.sh to create
latest list of healable and non healable entries and "heal" "noheal" files.

7 - Based on the number of entries, these files might take time to get and set the
stats and xattrs of entries.
