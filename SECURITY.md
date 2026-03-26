# Security Policy

## Supported Versions

We release security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 2.2.x   | :white_check_mark: |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

### How to Report

1. **GitHub Security Advisory** (Preferred)
   - Go to the repository's Security tab
   - Click "Report a vulnerability"
   - Fill out the advisory form with details

2. **Email** (Alternative)
   - Send details to the repository maintainers
   - Include "SECURITY" in the subject line
   - Provide detailed information about the vulnerability

### What to Include

Please include the following information:
- Type of vulnerability
- Full paths of affected source files
- Location of the affected code (tag/branch/commit)
- Step-by-step instructions to reproduce
- Proof-of-concept or exploit code (if possible)
- Impact of the vulnerability
- Suggested fix (if any)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: Within 7 days
  - High: Within 30 days
  - Medium: Within 90 days
  - Low: Next release cycle

### Disclosure Policy

- We will acknowledge receipt of your report
- We will confirm the vulnerability and determine its impact
- We will release a fix as soon as possible
- We will publicly disclose the vulnerability after a fix is available
- We will credit you for the discovery (unless you prefer to remain anonymous)

## Security Best Practices

### For Deployment

1. **Credentials**
   - Never commit `.env` files
   - Use AWS SSM/Secrets Manager for sensitive data
   - Rotate credentials regularly
   - Use IAM roles instead of access keys when possible

2. **Network Security**
   - Deploy in private subnets
   - Use security groups to restrict access
   - Enable VPC Flow Logs
   - Use AWS PrivateLink for AWS services

3. **Encryption**
   - Enable encryption at rest for RDS
   - Enable encryption at rest for EFS
   - Use HTTPS/TLS for all external communication
   - Enable SSL for RDS connections

4. **Access Control**
   - Follow principle of least privilege
   - Use IAM roles with minimal permissions
   - Enable MFA for AWS accounts
   - Regularly audit IAM permissions

5. **Monitoring**
   - Enable CloudTrail logging
   - Set up CloudWatch alarms
   - Monitor for unusual activity
   - Regular security audits

### For Development

1. **Code Security**
   - Run security scanners on code
   - Keep dependencies up to date
   - Review third-party dependencies
   - Use signed commits

2. **Container Security**
   - Use official base images
   - Scan images for vulnerabilities
   - Keep images updated
   - Use minimal base images

3. **Kubernetes Security**
   - Enable Pod Security Standards
   - Use Network Policies
   - Run containers as non-root
   - Drop unnecessary capabilities

## Known Security Considerations

### Current Implementation

1. **SSL Termination at ALB**
   - Traffic encrypted from users to ALB
   - HTTP used between ALB and pods (within VPC)
   - Acceptable for internal deployments
   - See ISSUE-024 for end-to-end encryption option

2. **Proxy Configuration**
   - Proxy credentials may be visible in pod specs
   - Use authenticated proxies with caution
   - Consider using AWS PrivateLink instead

3. **Owner Credentials**
   - Auto-generated passwords stored in AWS SSM
   - Change default password after first login
   - Enable MFA for owner account in n8n

## Security Updates

Subscribe to repository notifications to receive security updates:
- Watch the repository on GitHub
- Enable security alerts
- Check CHANGELOG.md for security fixes

## Questions?

For security-related questions that are not vulnerabilities, please open a discussion or contact the maintainers.

Thank you for helping keep n8n-on-aws-eks secure! 🔒
