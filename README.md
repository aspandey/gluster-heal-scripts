# gluster-heal-scripts
Scripts to correct file fragments extended attributes to heal those files.

Following are the guidlines/suggestions to use these scripts.

1 - Make sure NO IO is going on for the files for which we are making changes
in extended attributes using correct_pending_heals.sh.

2 - There should be no heal going on for the file for which xattrs are being
set by correct_pending_heals.sh. Disable the self heal while running this script.

3 - All the bricks of the volume should be UP to identify good and bad fragments
to identify if an entry is healable or not.

4 - if correct_pending_heals.sh is stopped in the middle while it was processing
healable entries, it is suggested re-run gfid_needing_heal_parallel.sh to create
latest list of healable and non healable entries and "heal" "noheal" files

5 - Based on the number of entries, these files might take time to get and set the
stats and xattrs of entries.
