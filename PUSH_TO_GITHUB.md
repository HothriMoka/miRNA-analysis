# How to Push to GitHub

Your local git repository is ready! Follow these steps to push to GitHub:

## Step 1: Create GitHub Repository

1. Go to https://github.com
2. Click the "+" icon → "New repository"
3. Repository name: `mouse_smallRNA-pipeline`
4. Description: "Mouse small RNA-seq analysis pipeline with miRNA detection"
5. **Keep it Public or Private** (your choice)
6. **DO NOT** initialize with README, .gitignore, or license (we already have these)
7. Click "Create repository"

## Step 2: Link Local Repository to GitHub

GitHub will show you commands. Use these:

```bash
cd /home/hmoka2/mnt/storage/bioinformatics/users/hmoka/mouse_smallRNA-pipeline

# Add remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/mouse_smallRNA-pipeline.git

# Or use SSH (recommended if you have SSH keys set up)
git remote add origin git@github.com:YOUR_USERNAME/mouse_smallRNA-pipeline.git

# Push to GitHub
git push -u origin main
```

## Step 3: Verify

Visit your repository URL:
`https://github.com/YOUR_USERNAME/mouse_smallRNA-pipeline`

## Current Repository Status

✅ Git initialized
✅ Email configured: h.moka@lms.mrc.ac.uk
✅ Username configured: hmoka2
✅ All files committed
✅ Branch: main
✅ Ready to push!

## What's Included

- Core pipeline scripts (01, 02, 03)
- Python helper scripts
- Module loading script
- Comprehensive README
- Quick start guide
- SLURM usage guide
- Detailed methodology
- .gitignore (excludes large files)
- MIT License

## What's Excluded (via .gitignore)

- references/ (31GB - too large for git)
- logs/ (temporary files)
- *_output/ (analysis results)
- Test data

## Alternative: Push to GitLab or Other

If you prefer GitLab (e.g., gitlab.com/lms or institutional GitLab):

```bash
git remote add origin https://gitlab.com/YOUR_USERNAME/mouse_smallRNA-pipeline.git
git push -u origin main
```

## Need Help?

If you encounter authentication issues:
- For HTTPS: You'll need a Personal Access Token (not password)
- For SSH: You'll need SSH keys set up

Generate personal access token at:
- GitHub: Settings → Developer settings → Personal access tokens
- GitLab: Preferences → Access Tokens
