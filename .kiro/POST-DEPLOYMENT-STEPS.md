# Post-Deployment Steps

**Required manual steps after automated deployment**

---

## 1. Community Edition Registration (Required)

**Why**: Enables full n8n functionality including:
- Community support access
- Workflow templates
- Update notifications
- All integrations and features

**Steps**:

1. Access your n8n instance:
   ```
   https://your-domain.com
   ```

2. Click **"Register for community edition"** (or similar prompt)

3. Accept the terms and conditions

4. Provide registration email:
   ```
   dl.it.cloudops@tweglobal.com
   ```

5. Complete registration

**Note**: 
- This is a **one-time** manual step (cannot be automated)
- Registration data is stored in RDS database
- Persists across pod restarts and upgrades
- Required for full functionality

---

## 2. Create Owner Account (If Not Auto-Created)

If you didn't use the automatic owner credentials secret:

1. On first access, you'll see the setup screen

2. Create owner account:
   - **Email**: dl.it.cloudops@tweglobal.com
   - **First Name**: TWE
   - **Last Name**: CloudOps
   - **Password**: (secure password)

3. Save credentials in password manager

**Automatic Setup** (Optional):

```bash
kubectl create secret generic n8n-owner-credentials -n n8n \
  --from-literal=email='dl.it.cloudops@tweglobal.com' \
  --from-literal=password='YourSecurePassword123!' \
  --from-literal=first_name='TWE' \
  --from-literal=last_name='CloudOps'

kubectl rollout restart deployment/n8n -n n8n
```

Then delete the secret:
```bash
kubectl delete secret n8n-owner-credentials -n n8n
```

---

## 3. Test Workflow Creation

1. Click **"Create new workflow"**

2. Add a **Manual Trigger** node

3. Add an **HTTP Request** node:
   - Method: GET
   - URL: https://api.github.com/zen

4. Connect the nodes

5. Click **"Execute Workflow"**

6. Verify output appears

7. **Save** the workflow

8. **Activate** the workflow

**Expected Result**: Workflow saves and activates successfully

---

## 4. Configure Credentials (If Needed)

For workflows that need external service access:

1. Go to **Credentials** menu

2. Click **"Add Credential"**

3. Select credential type (AWS, GitHub, Slack, etc.)

4. Configure with appropriate credentials

5. Test connection

6. Save

---

## 5. Set Up Backup Schedule (Recommended)

```bash
# Test manual backup
./scripts/backup.sh

# Verify backup created
ls -lh backups/

# Set up automated backups (cron or scheduled task)
# Example: Daily at 2 AM
0 2 * * * /path/to/scripts/backup.sh
```

---

## 6. Configure Monitoring Alerts (Recommended)

Set up CloudWatch alarms for:

- n8n pod down
- RDS high CPU
- RDS low storage
- ALB unhealthy targets

```bash
# Example: Create pod down alarm
aws cloudwatch put-metric-alarm \
  --alarm-name n8n-pod-down \
  --alarm-description "Alert when n8n pod is not running" \
  --metric-name pod_number_of_containers \
  --namespace ContainerInsights \
  --statistic Average \
  --period 300 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --region ap-southeast-2
```

---

## 7. Document Access Information

Create internal documentation with:

- **URL**: https://your-domain.com
- **Owner Email**: dl.it.cloudops@tweglobal.com
- **Network Requirements**: Corporate network (10.0.0.0/8) or VPN
- **Support Contact**: CloudOps team
- **Backup Location**: S3 bucket or local path
- **Monitoring Dashboard**: CloudWatch or Grafana URL

---

## 8. User Training (If Applicable)

If deploying for team use:

1. Create user accounts (Settings → Users)
2. Assign appropriate roles
3. Provide training on:
   - Workflow creation
   - Node usage
   - Credential management
   - Best practices

---

## Verification Checklist

After completing post-deployment steps:

- [ ] Community edition registered
- [ ] Owner account created and accessible
- [ ] Test workflow created and executed successfully
- [ ] Workflow saved to database (persists after pod restart)
- [ ] Credentials configured (if needed)
- [ ] Backup tested and working
- [ ] Monitoring alerts configured
- [ ] Access documented
- [ ] Team trained (if applicable)

---

## Troubleshooting

### Can't Register Community Edition

**Issue**: Registration fails or times out

**Check**:
1. Proxy configured in n8n pod?
   ```bash
   kubectl get deployment n8n -n n8n -o yaml | grep -A 3 HTTP_PROXY
   ```

2. Test internet access from pod:
   ```bash
   kubectl exec -it deployment/n8n -n n8n -- curl -v https://n8n.io
   ```

**Fix**: Ensure proxy environment variables are set (already configured in manifests)

---

### Owner Account Not Auto-Created

**Issue**: Secret created but account not appearing

**Check**:
1. Secret exists?
   ```bash
   kubectl get secret n8n-owner-credentials -n n8n
   ```

2. Pod restarted after secret creation?
   ```bash
   kubectl rollout restart deployment/n8n -n n8n
   ```

3. Check pod logs:
   ```bash
   kubectl logs -n n8n -l app=n8n --tail=50
   ```

---

### Workflow Not Saving

**Issue**: Workflows don't persist after pod restart

**Check**:
1. Database connection working?
   ```bash
   kubectl logs -n n8n -l app=n8n | grep -i database
   ```

2. RDS accessible?
   ```bash
   kubectl run test-db --image=postgres:16 --rm -it --restart=Never -- \
     psql -h RDS_ENDPOINT -U n8nuser -d n8n
   ```

**Expected**: Workflows should save to RDS and persist

---

## Next Steps

After completing post-deployment steps:

1. **Production Use**: Start creating production workflows
2. **Monitoring**: Review CloudWatch metrics regularly
3. **Backups**: Verify automated backups running
4. **Updates**: Plan for n8n version updates
5. **Scaling**: Monitor usage and scale as needed

---

**Status**: Post-deployment steps documented  
**Last Updated**: 2026-03-25
