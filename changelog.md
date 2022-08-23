# mountdrive-0.0.3
Fixed: If drive not present at boot system would hang until user hit the `s` (*skip*) key
 - mount parameter changed from `defaults,noatime` to `defaults,noatime,nofail`. This ensure system continue startup even when drive is missing. Drive can be connected later where command `sudo mount -a` will mount it as usual with settings from the `fstab`.
 - added arguments --version and --help (*usage*) 
 - yes/no dialog now accept `Enter` key for default value [Y/n] 