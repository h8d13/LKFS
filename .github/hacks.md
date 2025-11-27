## Hacks that were used

### Shell Configuration Trick

**The Problem:** Alpine's ash shell doesn't auto-load configs like bash does with `.bashrc`

**The Solution:** Chain `.profile` → `.ashrc` using the `ENV` variable

1. **`profile.sh`** creates `/root/.profile` with:
   ```sh
   export ENV=$HOME/.ashrc
   ```
   This tells ash: "auto-source `.ashrc` on every shell startup"

2. **`config.conf`** gets copied to `/root/.ashrc` and contains:
   - Custom colored prompt (PS1)
   - Proper PATH with `/sbin:/usr/sbin`
   - Aliases (`ll`, `apkli`)

**Result:** Every time you enter the chroot, ash reads `.profile`, which tells it to load `.ashrc`, giving you a fully customized shell without modifying Alpine's base files.

### Assets Folder Pattern

Instead of baking configs into the tarball:
- Keep all configs in `/assets` on the host
- Copy them into chroot during `chroot_launcher.sh`
- Modify anytime without re-downloading Alpine (3.3MB stays clean)
- Easy git version control

Files copied:
- `config.conf` → `/root/.ashrc` (shell config)
- `profile.sh` → generates `/root/.profile` (ENV bootstrap)
- `mods/*.sh` → `/etc/profile.d/` (login scripts for logo, welcome msg, version)
