# User Management Automation (SysOps Challenge)

## Project Overview
**User Management Automation** is a Bash script (`create_users.sh`) that automates onboarding by creating Linux user accounts from a simple input file. It ensures each new developer account is created consistently and securely:
- Primary group named after the username.
- Supplementary groups from input.
- Secure home directory (`/home/username`) with correct ownership and permissions.
- Random 12-character password set and stored securely.
- Full audit logging of actions.
----------------------------------------------------------------------------------------------------

## Project Purpose and Design Goals 

* Automate Linux user onboarding with secure, consistent, and error-free account creation.
* Replace manual user setup with a fully automated, audit-ready workflow.
* Ensure strong security for passwords, home directories, and logs.
* Security-focused design using strict permissions and strong password generation.
* Fully automated creation of users, groups, home directories, and credentials.
* Idempotent behavior that safely handles existing users and groups.
* Comprehensive logging for auditing and troubleshooting.
* Portable, maintainable script structure usable across Linux/WSL systems.
* Admin-friendly workflow with simple commands and clear output messages.

----------------------------------------------------------------------------------------------------

## Project Folder Structure
```
User_Management_Automation/
├── create_users.sh               # Main automation script
├── users.txt                     # Input file: username;group1,group2
├── README.md                     # Project documentation
```
# System-generated directories (NOT inside project folder):
```
/var/secure/
└── user_passwords.txt            # Real secure credentials (root only, 600)

/var/log/
└── user_management.log           # Full audit log (root only, 600)
```
----------------------------------------------------------------------------------------------------

## Architecture Diagram

```

+---------------------+       +-----------------------+        +-------------------+
|   Admin / CI        |  -->  |  create_users.sh      |  --->  |  System (Linux)   |
| (runs script / git) |       | (parses users.txt)    |        | - useradd/usermod |
+---------------------+       +-----------------------+        | - creates /home   |
        |                             |                        +-------------------+
        |                             |                                |
        |                             v                                v
        |                     +---------------+               +-----------------------+
        |                     | /var/secure/  |               | /var/log/             |
        |                     | user_passwords|               | user_management.log   |
        |                     +---------------+               +-----------------------+
        |                             ^                                ^
        |                             |                                |
        +-----------------------------+--------------------------------+
                      (secure storage & audit; root-only)

```
----------------------------------------------------------------------------------------------------
## How to clone from GitHub
If you have a GitHub repo (replace with your repo URL):
```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```
----------------------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------------------

## Input file format (`users.txt`) — example
```
# username; groups
girish;sudo,dev,www-data
rahul;sudo,dev,www-data
leelavamsi;dev,www-data
# blank lines and comments are ignored

```
----------------------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------------------

## What the script does

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

----------------------------------------------------------------------------------------------------

## Expected results / sample outputs

After running the script with the example `users.txt`, you should see:

### `/var/secure/user_passwords.txt` (root-owned, mode 600)
```
girish:PAGBtuyQ97fU
rahul:6u_jbe@l_5#r
leelavamsi:mxf=by7@cYkA

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
# Verifying User Details (User Information Commands)

After running the user management automation script, you should verify whether each user, group, and home directory was created correctly. Linux provides multiple built-in commands that allow you to confirm this.

----------------------------------------------------------------------------------------------------

## 1. Check User Details Using `id username`

This command shows the user’s UID, GID, and all supplementary groups.

### **Command:**

```
id rahul
```

### **Sample Output:**

```
uid=1002(rahul) gid=1002(rahul) groups=1002(rahul),27(sudo),1003(dev),33(www-data)
```

### **Explanation:**

* `uid=1002` → Rahul’s unique user ID
* `gid=1002` → Primary group with the same name as the username
* `groups=` → All assigned supplementary groups

----------------------------------------------------------------------------------------------------

## 2. Check User Account Entry Using `getent passwd username`

This confirms the user exists in the system’s account database.

### **Command:**

```
getent passwd rahul
```

### **Sample Output:**

```
rahul:x:1002:1002::/home/rahul:/bin/bash
```

### **Explanation:**

* `1002:1002` → User ID and Group ID
* `/home/rahul` → Home directory created by the script
* `/bin/bash` → Default shell assigned to the user

----------------------------------------------------------------------------------------------------

## 3. Check Group Details Using `getent group groupname`

This confirms that a group exists and lists all its members.

### **Command:**

```
getent group dev
```

### **Sample Output:**

```
dev:x:1003:rahul,manoj
```

### **Explanation:**

* `1003` → Group ID of the `dev` group
* `rahul,manoj` → Users added to this group

----------------------------------------------------------------------------------------------------

## 4. Check Home Directory Permissions

Ensures the script correctly set permissions to `700`.

### **Command:**

```
sudo ls -ld /home/rahul
```

### **Sample Output:**

```
drwx------ 2 rahul rahul 4096 Nov 13 10:42 /home/rahul
```

### **Explanation:**

* `drwx------` → Permission `700`, meaning only the user and root can access this folder
* Ownership belongs to `rahul:rahul` as required

----------------------------------------------------------------------------------------------------

These verification steps demonstrate the successful creation and configuration of users, groups, and home directories according to the SysOps User Management Automation requirements.


----------------------------------------------------------------------------------------------------

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
sudo ls -ld /home/rahul /home/girish /home/leelavamsi
sudo stat /home/rahul

# Verify user and group entries
getent passwd rahul
getent group rahul
id rahul
```

**Important:** `/var/secure` is `700` and files are `600` — only root can read them. This is by design.

----------------------------------------------------------------------------------------------------

## Security considerations & recommendations

- **Protect credentials**: Move credentials to a secrets manager (HashiCorp Vault, AWS Secrets Manager) and delete local copy after provisioning.
- **SSH keys**: Prefer SSH public-key provisioning in production.
- **First-login reset**: Script sets `chage -d 0` so users must change default password.
- **Log rotation**: Configure `logrotate` for `/var/log/user_management.log`.
- **Audit & retention**: Keep an audit policy for credential files and delete them after use.
- **Least privilege**: Files in `/var/secure` remain root-only.

----------------------------------------------------------------------------------------------------

## Troubleshooting 
- `chpasswd` fails with `pam_chauthtok()` — check `/etc/shadow` permissions and filesystem status:
```bash
ls -l /etc/shadow
sudo chown root:shadow /etc/shadow
sudo chmod 640 /etc/shadow
```
- `tr` errors in password generation — script enforces `LC_ALL=C` to avoid locale collation errors.
- Permissions errors when viewing `/var/secure` in Explorer — expected; use `take_outputs_screenshots.sh` to generate readable copies.

----------------------------------------------------------------------------------------------------
### 🧑‍💻 Developer

**Name:** Venuthurla Siva Chaithanya  
**Email:**  chaithanyav.0203@gmail.com
**GitHub:** [@Chaithanya013](https://github.com/Chaithanya013)