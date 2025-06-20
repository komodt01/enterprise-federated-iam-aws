# Linux Commands Reference - Enterprise Federated IAM Project

This document contains all Linux commands used during the Enterprise Federated IAM project implementation.

## Terraform Commands

### **Initial Setup and Validation**
```bash
# Initialize Terraform in project directory
terraform init

# Validate Terraform configuration syntax
terraform validate

# Format Terraform files for consistency
terraform fmt

# Show current Terraform version
terraform version
```

### **Planning and Deployment**
```bash
# Preview changes before applying
terraform plan

# Apply changes to deploy infrastructure
terraform apply

# Apply changes without confirmation prompt
terraform apply -auto-approve

# Show current state of deployed resources
terraform show

# List all resources in current state
terraform state list
```

### **Cleanup and Maintenance**
```bash
# Destroy all Terraform-managed infrastructure
terraform destroy

# Destroy specific resource
terraform destroy -target=resource_type.resource_name

# Refresh state to match real infrastructure
terraform refresh

# View Terraform outputs
terraform output
```

## File Management Commands

### **Navigation and File Operations**
```bash
# Change to project directory
cd ~/terraform/enterprise-federated-iam

# List files with details
ls -la

# Create new directory
mkdir -p terraform/modules

# Copy files
cp main.tf main.tf.backup

# Move/rename files
mv old_filename.tf new_filename.tf

# View file contents
cat terraform.tfvars

# Edit file with nano
nano main.tf

# Edit file with vim
vim variables.tf
```

### **File Permissions and Ownership**
```bash
# Make file executable
chmod +x deploy.sh

# Change file permissions to read-only
chmod 644 terraform.tfvars

# Change ownership of files
chown user:group *.tf
```

## Text Processing and Search

### **File Content Analysis**
```bash
# Search for specific text in files
grep -r "DemoSAMLProvider" .

# Search for patterns in Terraform files
grep -n "aws_iam_role" *.tf

# Count lines in file
wc -l main.tf

# Show first few lines of file
head -n 20 terraform.tfvars

# Show last few lines of file
tail -n 10 main.tf

# Search and replace text
sed 's/old_text/new_text/g' main.tf > main_updated.tf
```

### **JSON/Configuration File Processing**
```bash
# Pretty print JSON
cat config.json | jq '.'

# Extract specific JSON values
jq '.audience' saml_config.json

# Validate JSON syntax
python -m json.tool < config.json
```

## System Information and Monitoring

### **System Status**
```bash
# Check disk space
df -h

# Check memory usage
free -h

# Check running processes
ps aux | grep terraform

# Monitor system resources
top

# Check network connectivity
ping aws.amazon.com

# Test DNS resolution
nslookup signin.aws.amazon.com
```

### **Environment Variables**
```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="us-east-1"

# View environment variables
env | grep AWS

# Unset environment variable
unset AWS_ACCESS_KEY_ID
```

## Git Version Control Commands

### **Repository Management**
```bash
# Initialize git repository
git init

# Add files to staging
git add .
git add main.tf variables.tf

# Commit changes
git commit -m "Add initial Terraform configuration"

# View commit history
git log --oneline

# Check repository status
git status

# View differences
git diff main.tf
```

### **Branch Management**
```bash
# Create new branch
git checkout -b feature/saml-integration

# Switch branches
git checkout main

# Merge branch
git merge feature/saml-integration

# Delete branch
git branch -d feature/saml-integration
```

## Archive and Backup Commands

### **File Compression**
```bash
# Create tar archive of project
tar -czf enterprise-iam-backup.tar.gz *.tf *.md

# Extract tar archive
tar -xzf enterprise-iam-backup.tar.gz

# Create zip archive
zip -r project-backup.zip terraform/

# Extract zip archive
unzip project-backup.zip
```

### **File Synchronization**
```bash
# Sync files between directories
rsync -av terraform/ backup/terraform/

# Copy files over SSH
scp *.tf user@remote-server:/path/to/destination/
```

## AWS CLI Commands (if used)

### **AWS Configuration**
```bash
# Configure AWS CLI
aws configure

# List AWS CLI configuration
aws configure list

# Test AWS CLI access
aws sts get-caller-identity

# List S3 buckets
aws s3 ls

# Describe IAM roles
aws iam list-roles --query 'Roles[?contains(RoleName, `federated`)]'
```

## Debugging and Troubleshooting

### **Log Analysis**
```bash
# View Terraform debug output
TF_LOG=DEBUG terraform apply

# Redirect output to file
terraform plan > plan_output.txt 2>&1

# Monitor file changes
watch -n 5 'ls -la *.tf'

# Real-time file monitoring
tail -f terraform.log
```

### **Process Management**
```bash
# Find process by name
pgrep terraform

# Kill process by PID
kill -9 <process_id>

# Kill all terraform processes
pkill terraform
```

## File Editing Shortcuts

### **Nano Editor**
```bash
# Save file: Ctrl+O
# Exit: Ctrl+X
# Search: Ctrl+W
# Go to line: Ctrl+_
```

### **Vim Editor**
```bash
# Enter insert mode: i
# Save and exit: :wq
# Exit without saving: :q!
# Search: /search_term
# Replace: :%s/old/new/g
```

## Directory Structure Commands

### **Project Organization**
```bash
# Create standard project structure
mkdir -p {terraform/{modules,environments},docs,scripts}

# Tree view of directory structure (if tree is installed)
tree .

# Create symbolic links
ln -s /path/to/source/file link_name

# Find files by type
find . -name "*.tf" -type f
```

## Network and Connectivity

### **Network Testing**
```bash
# Test HTTP connectivity
curl -I https://signin.aws.amazon.com

# Download files
wget https://example.com/file.txt

# Test port connectivity
telnet hostname 443

# Check network routing
traceroute aws.amazon.com
```

## Performance and Resource Monitoring

### **Resource Usage**
```bash
# Monitor CPU usage
htop

# Check I/O statistics
iostat

# Monitor network usage
iftop

# Check disk usage by directory
du -sh *
```

---

## Command Usage Notes

- **Always run `terraform plan` before `terraform apply`** to preview changes
- **Use `terraform fmt` regularly** to maintain consistent code formatting
- **Keep backups** of working configurations before major changes
- **Use version control** (git) to track all configuration changes
- **Set appropriate file permissions** for sensitive files like terraform.tfvars
- **Use environment variables** for AWS credentials rather than hardcoding them

## Safety Commands

```bash
# Make terraform.tfvars read-only to prevent accidental modification
chmod 444 terraform.tfvars

# Create backup before major changes
cp main.tf main.tf.backup.$(date +%Y%m%d_%H%M%S)

# Validate configuration before applying
terraform validate && terraform plan
```