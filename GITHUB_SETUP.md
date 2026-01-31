# 🔗 GitHub Setup Guide

This guide will help you connect your local Phase 1 project to GitHub.

## 📋 Prerequisites

Before you begin, make sure you have:
- ✅ A GitHub account (create one at https://github.com/signup if needed)
- ✅ Git installed on your local machine
- ✅ This project is already initialized with git and has an initial commit

## 🎯 Step-by-Step Instructions

### Option 1: Using GitHub Personal Access Token (Recommended for Beginners)

#### Step 1: Create a New GitHub Repository

1. **Go to GitHub** and sign in to your account
2. **Click the "+" icon** in the top-right corner and select "New repository"
3. **Fill in the repository details**:
   - **Repository name**: `bespoke-labs-assignment-part1` (or your preferred name)
   - **Description**: "Bespoke Labs Take-Home Assignment - Phase 1: Kubernetes Wiki Service"
   - **Visibility**: 
     - Choose **Private** (recommended for assignment work)
     - Or **Public** if you want to showcase it
   - **DO NOT** initialize with README, .gitignore, or license (we already have these!)
4. **Click "Create repository"**

#### Step 2: Generate a Personal Access Token

1. **Click your profile picture** (top-right) → **Settings**
2. **Scroll down** and click **"Developer settings"** (bottom of left sidebar)
3. **Click "Personal access tokens"** → **"Tokens (classic)"**
4. **Click "Generate new token"** → **"Generate new token (classic)"**
5. **Fill in the token details**:
   - **Note**: "Bespoke Labs Assignment" (or descriptive name)
   - **Expiration**: 30 days (or your preference)
   - **Select scopes**: Check **"repo"** (Full control of private repositories)
6. **Click "Generate token"**
7. **IMPORTANT**: Copy the token immediately! You won't be able to see it again.
   - Save it in a secure location (password manager recommended)

#### Step 3: Connect Your Local Repository to GitHub

Run these commands in your terminal:

```bash
# Navigate to your project
cd /home/ubuntu/assignment-part1

# Add your GitHub repository as the remote origin
# Replace YOUR_USERNAME and YOUR_REPO_NAME with your actual GitHub username and repository name
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git

# Verify the remote was added correctly
git remote -v

# Push your code to GitHub
# When prompted for password, paste your Personal Access Token (not your GitHub password!)
git push -u origin main
```

**Example**:
```bash
# If your username is "johndoe" and repo is "bespoke-labs-assignment-part1"
git remote add origin https://github.com/johndoe/bespoke-labs-assignment-part1.git
git push -u origin main
```

When prompted:
- **Username**: Your GitHub username
- **Password**: Paste your Personal Access Token (starts with `ghp_`)

---

### Option 2: Using SSH Keys (Recommended for Regular Git Users)

#### Step 1: Create a New GitHub Repository
Follow the same steps as Option 1, Step 1.

#### Step 2: Set Up SSH Keys (if you haven't already)

1. **Check if you already have SSH keys**:
   ```bash
   ls -la ~/.ssh
   ```
   Look for files like `id_rsa.pub`, `id_ed25519.pub`, etc.

2. **Generate a new SSH key** (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
   Press Enter to accept the default location and optionally set a passphrase.

3. **Add SSH key to ssh-agent**:
   ```bash
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```

4. **Copy the SSH public key**:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
   Copy the entire output.

5. **Add SSH key to GitHub**:
   - Go to GitHub → **Settings** → **SSH and GPG keys**
   - Click **"New SSH key"**
   - **Title**: "My Development Machine" (or descriptive name)
   - **Key**: Paste the public key you copied
   - Click **"Add SSH key"**

#### Step 3: Connect Your Local Repository to GitHub

```bash
# Navigate to your project
cd /home/ubuntu/assignment-part1

# Add your GitHub repository as the remote origin (SSH URL)
# Replace YOUR_USERNAME and YOUR_REPO_NAME
git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPO_NAME.git

# Verify the remote was added correctly
git remote -v

# Push your code to GitHub
git push -u origin main
```

---

### Option 3: Using GitHub CLI (Easiest, if installed)

#### Step 1: Install GitHub CLI (if not already installed)

**macOS**:
```bash
brew install gh
```

**Linux**:
```bash
# Debian/Ubuntu
sudo apt install gh

# Fedora/CentOS
sudo dnf install gh
```

**Windows**:
```bash
# Using winget
winget install --id GitHub.cli
```

#### Step 2: Authenticate with GitHub

```bash
gh auth login
```

Follow the prompts:
1. Choose **GitHub.com**
2. Choose **HTTPS** or **SSH** (HTTPS is simpler)
3. Authenticate via web browser

#### Step 3: Create Repository and Push

```bash
# Navigate to your project
cd /home/ubuntu/assignment-part1

# Create the GitHub repository and push in one command!
gh repo create bespoke-labs-assignment-part1 --private --source=. --remote=origin --push

# Or for a public repository:
gh repo create bespoke-labs-assignment-part1 --public --source=. --remote=origin --push
```

---

## ✅ Verify Your Setup

After pushing, verify everything worked:

1. **Check your GitHub repository** in your browser:
   ```
   https://github.com/YOUR_USERNAME/YOUR_REPO_NAME
   ```

2. **You should see**:
   - ✅ README.md displayed on the main page
   - ✅ All your project files
   - ✅ 1 commit: "Initial commit: Phase 1 project structure setup"

3. **Verify remote connection locally**:
   ```bash
   cd /home/ubuntu/assignment-part1
   git remote -v
   git status
   ```

---

## 🔄 Future Workflow

After initial setup, your typical workflow will be:

```bash
# Make changes to your files
# ... edit files ...

# Check what changed
git status

# Stage your changes
git add .

# Commit your changes
git commit -m "Descriptive commit message"

# Push to GitHub
git push
```

**Best Practices**:
- ✅ Commit often with clear, descriptive messages
- ✅ Push regularly to keep GitHub in sync
- ✅ Use branches for major features: `git checkout -b feature/database-migration`
- ✅ Write meaningful commit messages that explain *why* not just *what*

---

## 🆘 Troubleshooting

### Problem: "remote origin already exists"
```bash
# Remove the existing remote and add the correct one
git remote remove origin
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
```

### Problem: "Authentication failed" (HTTPS)
- Make sure you're using your **Personal Access Token**, not your GitHub password
- GitHub no longer accepts passwords for Git operations
- Generate a new token if needed (see Option 1, Step 2)

### Problem: "Permission denied (publickey)" (SSH)
- Make sure your SSH key is added to GitHub (see Option 2, Step 2)
- Test SSH connection: `ssh -T git@github.com`
- You should see: "Hi YOUR_USERNAME! You've successfully authenticated..."

### Problem: "src refspec main does not match any"
```bash
# Make sure you have at least one commit
git log
# If no commits, make one:
git add .
git commit -m "Initial commit"
```

---

## 📚 Additional Resources

- [GitHub Documentation](https://docs.github.com/)
- [Git Basics](https://git-scm.com/book/en/v2/Getting-Started-Git-Basics)
- [Connecting to GitHub with SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [GitHub CLI Manual](https://cli.github.com/manual/)

---

## 🎉 Next Steps

Once your repository is on GitHub:

1. ✅ Share the repository URL with your Bespoke Labs coordinator (if required)
2. ✅ Continue with Phase 2: Database Migration to PostgreSQL
3. ✅ Keep committing and pushing as you progress through the phases
4. ✅ Consider adding a `.github/workflows/` directory for CI/CD later

---

**Remember**: This localhost refers to localhost of the computer that I'm using to run the application, not your local machine. To access it locally or remotely, you'll need to deploy the application on your own system.

Good luck with your assignment! 🚀
