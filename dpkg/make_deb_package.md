# Make deb package
Create packages ready for install on Debian system with `apt` command.
## Prepear files
Collect your complete project in a single directory named 'applicationname-version_all'. The optional <i>all</i> at the end are here are ment to tell that package is not hardware specific.

mountdrive-0.0.3_all

Inside this directory create a directory structure identical to where your file(s) will be installed.
Then add a directory 'DEBIAN' where the deb packaging system will read its information from. 
This directory should minimum have a text file with the name 'control'.
<br /><br />
<i>Please see how the directory structure are organiced in the 'dpkp' directory.</i>
## Folder and script permissions
When all files are in its place run:

 - sudo chown root:root -R mountdrive-0.0.3_all
 - sudo chmod a+x mountdrive-0.0.3_all/usr/bin/mountdrive
 - dpkg -b mountdrive-0.0.3_all


Want a more detailed read get over to: https://www.senties-martinelli.com/articles/debian-packages