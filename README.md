# User Management Automation — README (Trainer-ready)

## Project Overview
**User Management Automation** is a Bash script (`create_users.sh`) that automates onboarding by creating Linux user accounts from a simple input file. It ensures each new developer account is created consistently and securely:
- Primary group named after the username.
- Supplementary groups from input.
- Secure home directory (`/home/username`) with correct ownership and permissions.
- Random 12-character password set and stored securely.
- Full audit logging of actions.

This README is trainer-ready and includes cloning instructions, precise commands to run, expected outputs, and screenshot guidance.

---

## Full Task Checklist (implemented)
The script implements every requirement from the SysOps challenge:

- Read lines formatted as `username;group1,group2,group3`.
- Skip lines that begin with `#`.
- Ignore whitespace around usernames and group names.
- Create a primary group named the same as the username.
- Create any supplementary groups and add the user to them.
- Create `/home/username` if it does not exist; set `chown username:username` and `chmod 700`.
- Generate a random 12-character password and set it for the user.
- Save `username:password` to **`/var/secure/user_passwords.txt`** with permissions `600`.
- Log all actions to **`/var/log/user_management.log`** with permissions `600`.
- Handle existing users and groups gracefully.
- Display clear, informative messages to stdout and log.
- Include in-script comments; provide this README.

---

## Repository files
- `create_users.sh` — main script (executable).
- `users.txt` — sample input.
- `take_outputs_screenshots.sh` — helper to collect outputs for demo (optional).
- Output files created by the script at runtime:
  - `/var/secure/user_passwords.txt` (root-owned, `600`)
  - `/var/log/user_management.log` (root-owned, `600`)
  - `/home/<username>` directories

---

## How to clone from GitHub
If you have a GitHub repo (replace with your repo URL):
```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```
---

## Preparation and safe setup (exact commands)
> Run these commands from the project folder. Use `sudo` where indicated.

1. Make the script executable:
```bash
chmod +x create_users.sh
```

2. Create secure storage and log files (task-mandated paths) and apply secure permissions:
```bash
sudo mkdir -p /var/secure
sudo chown root:root /var/secure
sudo chmod 700 /var/secure

sudo touch /var/secure/user_passwords.txt /var/log/user_management.log
sudo chown root:root /var/secure/user_passwords.txt /var/log/user_management.log
sudo chmod 600 /var/secure/user_passwords.txt /var/log/user_management.log
```

3. Ensure `users.txt` exists in your project folder (see example below).

---

## Input file format (`users.txt`) — example
```
# username; groups
girish;sudo,dev,www-data
rahul;sudo,dev,www-data
leelavamsi;dev,www-data
# blank lines and comments are ignored

```

Notes:
- Spaces are tolerated and ignored.
- Lines beginning with `#` are skipped.

---

## Running the script (example commands)
- Standard run (create users, do not reset existing passwords):
```bash
sudo ./create_users.sh -f users.txt
```

- Force password reset for listed users:
```bash
sudo ./create_users.sh -f users.txt --reset-password
```

- Dry-run mode (if implemented in your script) — shows planned actions without changing system:
```bash
sudo ./create_users.sh -f users.txt --dry-run
```

---

## What the script does (step-by-step)
1. **Preflight checks**: runs as root; ensures `/var/secure` exists and `/etc/shadow` is writable; creates files with secure perms.
2. **Read input**: reads each line, strips BOM and whitespace, skips comments, validates format.
3. **Username handling**: validates usernames against conservative rules (lowercase, digits, `_`, `-`); optionally normalizes to lowercase.
4. **Groups**: ensures primary group (username) exists; creates supplementary groups as needed.
5. **User creation**: creates user with `useradd` (home created); if user exists, ensures home exists and corrects ownership/perms.
6. **Home dir**: ensures `/home/username` present, `chown username:username`, `chmod 700`.
7. **Password**: generates robust 12-character password (`LC_ALL=C tr ...` fallback to `openssl`), sets it via `chpasswd`.
8. **Record credentials**: appends `username:password` to `/var/secure/user_passwords.txt` atomically (uses `flock` if available).
9. **Log actions**: writes INFO/WARN/ERROR messages with UTC timestamps to `/var/log/user_management.log`.
10. **Security post-actions**: marks password expired for first-login via `chage -d 0`.

---

## Expected results / sample outputs
After running the script with the example `users.txt`, you should see:

### `/var/secure/user_passwords.txt` (root-owned, mode 600)
```
light:Ab7fK2xQm9P1
siyoni:7TgR9pLm0Wq4
manoj:kQ8rV6sT2bZ9
```
> Each line is `username:password` (12 characters). This file is sensitive — keep it root-only.

### `/var/log/user_management.log` (root-owned, mode 600)
```
2025-11-13T09:57:26Z [INFO] Starting user creation (input=users.txt reset_existing=false)
2025-11-13T09:57:26Z [INFO] Processing user: girish (groups: sudo dev www-data)
2025-11-13T09:57:26Z [WARN] User already exists: girish
2025-11-13T09:57:26Z [INFO] Added girish to groups: sudo dev www-data
2025-11-13T09:57:26Z [INFO] Skipping password change for existing user girish (use --reset-password)
2025-11-13T09:57:26Z [INFO] Processing user: rahul (groups: sudo dev www-data)
2025-11-13T09:57:26Z [WARN] User already exists: rahul
2025-11-13T09:57:26Z [INFO] Added rahul to groups: sudo dev www-data
2025-11-13T09:57:26Z [INFO] Skipping password change for existing user rahul (use --reset-password)
2025-11-13T09:57:26Z [INFO] Processing user: leelavamsi (groups: dev www-data)
2025-11-13T09:57:26Z [WARN] User already exists: leelavamsi
2025-11-13T09:57:26Z [INFO] Added leelavamsi to groups: dev www-data
2025-11-13T09:57:26Z [INFO] Skipping password change for existing user leelavamsi (use --reset-password)
2025-11-13T09:57:26Z [INFO] Processing complete. Passwords saved to /var/secure/user_passwords.txt, logs to /var/log/user_management.log
2025-11-13T10:00:14Z [INFO] Starting user creation (input=users.txt reset_existing=true)
2025-11-13T10:00:14Z [INFO] Processing user: girish (groups: sudo dev www-data)
2025-11-13T10:00:14Z [WARN] User already exists: girish
2025-11-13T10:00:14Z [INFO] Added girish to groups: sudo dev www-data
2025-11-13T10:00:14Z [INFO] Set password for girish and saved to /var/secure/user_passwords.txt
2025-11-13T10:00:14Z [INFO] Processing user: rahul (groups: sudo dev www-data)
2025-11-13T10:00:14Z [WARN] User already exists: rahul
2025-11-13T10:00:14Z [INFO] Added rahul to groups: sudo dev www-data
2025-11-13T10:00:14Z [INFO] Set password for rahul and saved to /var/secure/user_passwords.txt
2025-11-13T10:00:14Z [INFO] Processing user: leelavamsi (groups: dev www-data)
2025-11-13T10:00:14Z [WARN] User already exists: leelavamsi
2025-11-13T10:00:14Z [INFO] Added leelavamsi to groups: dev www-data
2025-11-13T10:00:14Z [INFO] Set password for leelavamsi and saved to /var/secure/user_passwords.txt
2025-11-13T10:00:14Z [INFO] Processing complete. Passwords saved to /var/secure/user_passwords.txt, logs to /var/log/user_management.log

```

---

## Viewing the root directory and verification commands
Trainers often ask to inspect system artifacts — use these commands (as root):

```bash
# Confirm secure directory and files
sudo ls -ld /var/secure
sudo ls -l /var/secure/user_passwords.txt
sudo stat -c "%A %U %G %n" /var/secure/user_passwords.txt

# Confirm log file
sudo ls -l /var/log/user_management.log
sudo tail -n 50 /var/log/user_management.log

# Inspect home directories and permissions
sudo ls -ld /home/light /home/siyoni /home/manoj
sudo stat /home/light

# Verify user and group entries
getent passwd light
getent group light
id light
```

**Important:** `/var/secure` is `700` and files are `600` — only root can read them. This is by design.

---

---

## Security considerations & recommendations
- **Protect credentials**: Move credentials to a secrets manager (HashiCorp Vault, AWS Secrets Manager) and delete local copy after provisioning.
- **SSH keys**: Prefer SSH public-key provisioning in production.
- **First-login reset**: Script sets `chage -d 0` so users must change default password.
- **Log rotation**: Configure `logrotate` for `/var/log/user_management.log`.
- **Audit & retention**: Keep an audit policy for credential files and delete them after use.
- **Least privilege**: Files in `/var/secure` remain root-only.

---

## Troubleshooting (common issues)
- `chpasswd` fails with `pam_chauthtok()` — check `/etc/shadow` permissions and filesystem status:
```bash
ls -l /etc/shadow
sudo chown root:shadow /etc/shadow
sudo chmod 640 /etc/shadow
```
- `tr` errors in password generation — script enforces `LC_ALL=C` to avoid locale collation errors.
- Permissions errors when viewing `/var/secure` in Explorer — expected; use `take_outputs_screenshots.sh` to generate readable copies.

---

## Appendix — Full script
The authoritative `create_users.sh` script is included in the repository. Use it to reproduce runs described in this README.

---
### 🧑‍💻 Developer

**Name:** Venuthurla Siva Chaithanya  
**Email:**  chaithanyav.0203@gmail.com
**GitHub:** [@Chaithanya013](https://github.com/Chaithanya013)