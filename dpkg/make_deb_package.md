# Make deb package
Ready for install on Debian system with `apt` command.
<br />
If already downloaded use: sudo apt install ./mountdrive-0.0.2_all 
where `./` just means <i>this directory</i> - not to have `apt` looking in its packaging list.
<br />
More efficient is to use the direct internet path and let `apt` take care of the download before install.
## Prepear files
Have your complete project in a single directory named 'applicationname-version_all'. The optional <i>all</i> at the end are here ment to tell that package is not hardware specific.

mountdrive-0.0.2_all

Inside this directory create a directory structure identical to where your file(s) will be installed.
Then add a directory 'DEBIAN' where the deb packaging system will read its information from starting with a file named 'control'.
<i>See how the directory structure are organiced here in this 'dpkp' directory.</i>
## Folder and script permissions
When ready prepearing the files run:
sudo chown root:root -R mountdrive-0.0.2_all
sudo chmod a+x mountdrive-0.0.2_all/usr/bin/mountdrive
dpkg -b mountdrive-0.0.2_all


Want a more detailed read get over to: https://www.senties-martinelli.com/articles/debian-packages