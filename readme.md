# FoggyBack
A crappy set of bash scripts to do a simple rsync backup.

# Requires
A working rsync server

# Usage
1. Install the .sh files in /usr/sbin and the .time and .service file in /usr/lib/systemd/system.
2. Create a new module using your computer's hostname
3. Create initial backup: sudo /usr/sbin/foggyback.sh -i -h <rsync server>
4. Enable the time with "sudo systemctl enable salinasBackup.timer" to automate future backups
