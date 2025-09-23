# NetBird Access Review Process

This document defines the periodic review process for NetBird group memberships, ACLs, and network routes.

## Review Schedule

| Review Type | Frequency | Scope |
|-------------|-----------|-------|
| **Group Membership Review** | Monthly | User group assignments |
| **ACL Review** | Quarterly | Access control policies |
| **Network Routes Review** | Quarterly | Route configurations |
| **Comprehensive Review** | Annually | All components |

## Review Process

### Management Interface

NetBird administrative functions are managed through:
- **NetBird Management Dashboard**: https://app.netbird.io (or self-hosted instance)
- **NetBird Management API**: For programmatic access

**Note**: User management, groups, ACLs, and routes are **not** managed via the NetBird client CLI.

## Review Categories

### 1. Group Membership Review

**Checklist:**
- [ ] Verify user role assignments
- [ ] Check for inactive accounts
- [ ] Validate group membership changes
- [ ] Document access modifications

**Management:** Use NetBird Management Dashboard to review and modify group memberships.

### 2. Access Control Lists (ACLs) Review

**Checklist:**
- [ ] Review ACL rule configurations
- [ ] Validate network access permissions
- [ ] Check for overly permissive rules
- [ ] Verify security boundary enforcement

**Management:** Access ACL policies through NetBird Management Dashboard or API.

### 3. Network Routes Review

**Checklist:**
- [ ] Verify route configurations
- [ ] Check network segmentation
- [ ] Validate route priorities
- [ ] Review unused routes

**Commands:**
```bash
# List available network routes
netbird networks list

```

## Review Documentation

### Review Record Template

| Field | Details |
|-------|---------|
| **Review Date** | YYYY-MM-DD |
| **Reviewer** | Name and Title |
| **Review Type** | Monthly/Quarterly/Annual |
| **Changes Made** | Summary of modifications |
| **Next Review Date** | YYYY-MM-DD |

## Review Ownership and Change Management

### Review Ownership

| Review Type | Primary Owner | Secondary Owner | Approver |
|-------------|---------------|-----------------|----------|
| **Group Membership** | IT Security Manager | HR Representative | Department Head |
| **ACL Policies** | Network Administrator | Security Analyst | CISO |
| **Network Routes** | Network Administrator | Infrastructure Lead | IT Director |

### Change Documentation Requirements

**All access changes must include:**
- Business justification for the change
- Risk assessment (Low/Medium/High)
- Approval from designated authority
- Implementation date and time
- Rollback plan (if applicable)

**Change Documentation Template:**
```
Change ID: CHG-YYYYMMDD-XXX
Requester: [Name and Department]
Business Justification: [Reason for change]
Risk Level: [Low/Medium/High]
Approved By: [Approver Name and Date]
Implemented By: [Implementer Name]
Implementation Date: [YYYY-MM-DD HH:MM]
Rollback Plan: [Steps to reverse if needed]
Verification: [How success was confirmed]
```

### Exception Handling

**Emergency Access Exceptions:**
- Must be approved by CISO or delegate
- Limited to 24-hour duration maximum
- Require immediate documentation
- Subject to next-day review and formal approval

**Permanent Exceptions:**
- Require formal risk assessment
- Must be approved by IT Director and CISO
- Subject to quarterly review
- Documented with compensating controls

## Review Execution

### Pre-Review Preparation

1. **Access NetBird Management Dashboard**
2. **Export current configurations**
3. **Gather HR data for user status verification**
4. **Prepare review templates and checklists**

### Review Process

1. **Conduct systematic review** using provided checklists
2. **Document all findings** in review templates
3. **Identify required changes** and exceptions
4. **Obtain necessary approvals** for modifications
5. **Implement approved changes** through proper channels
6. **Verify changes** were applied correctly
7. **Update documentation** and schedule next review
