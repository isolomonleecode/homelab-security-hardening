# SESSION 7: SAML Security Training & Attack Lab

**Date:** 2025-11-01
**Focus:** SAML authentication security - from basics to exploitation
**Persona:** Security Analyst / Instructor
**Learning Path:** Week 1 - SAML Basics & Configuration

---

## Session Overview

This session focuses on building practical SAML security knowledge through hands-on configuration and testing. The learning path progresses from basic setup through security testing to real-world attack scenarios.

### Learning Objectives
1. **Week 1:** Configure SAML infrastructure (Keycloak IdP + SimpleSAMLphp SP)
2. **Week 2:** Security testing (SAML Tracer, signature validation, replay attacks)
3. **Week 3:** Offensive techniques (XML Signature Wrapping, attribute manipulation)
4. **Week 4:** Real-world integration (NextCloud, Grafana SAML SSO)

---

## Pre-Session Assessment

### Lab Infrastructure Status
```bash
# SAML lab containers
saml-idp-keycloak   - Up 47 hours - Port 8180
saml-sp-simple      - Up 47 hours - Port 8081
saml-sp-nextcloud   - Up 47 hours - Port 8082
saml-nextcloud-db   - Up 47 hours - Internal

# Infrastructure: ✅ HEALTHY
# Configuration: ❌ NOT STARTED
```

### Keycloak Configuration Status
```bash
curl http://localhost:8180/realms/saml-demo/.well-known/openid-configuration
# Output: {"error":"Realm does not exist"}
```

**Finding:** Keycloak is running but the realm hasn't been created yet.

**Assessment:** Student is at Week 1, Day 1 - Basic setup phase.

---

## Week 1: SAML Basics & Configuration

### Day 1 Goals
1. ✅ Verify lab infrastructure
2. Configure Keycloak realm "homelab"
3. Create test users (alice, bob)
4. Configure SAML client for SimpleSAMLphp
5. Download IdP metadata
6. Test basic SAML authentication

---

## Step 1: Keycloak Identity Provider Setup

### 1.1 Access Keycloak Admin Console

**URL:** http://localhost:8180
**Credentials:** admin / admin123

### 1.2 Create Realm

The realm is the logical boundary for users, clients, and security policies.

**Instructions:**
1. Click dropdown next to "master" (top-left)
2. Click "Create Realm"
3. Realm name: `homelab`
4. Click "Create"

**Why "homelab"?**
- Separates test environment from Keycloak's master realm
- Allows isolated SAML configuration
- Production best practice: never use master realm for applications

### 1.3 Create Test Users

**User 1: Alice (Regular User)**
1. Navigate to: Users → Create user
2. Username: `alice`
3. Email: `alice@homelab.local`
4. First name: `Alice`
5. Last name: `Anderson`
6. Email verified: ON
7. Click "Create"
8. Go to "Credentials" tab
9. Set password: `alice123`
10. Temporary: OFF
11. Click "Set password"

**User 2: Bob (Privileged User)**
1. Navigate to: Users → Create user
2. Username: `bob`
3. Email: `bob@homelab.local`
4. First name: `Bob`
5. Last name: `Builder`
6. Email verified: ON
7. Click "Create"
8. Go to "Credentials" tab
9. Set password: `bob123`
10. Temporary: OFF
11. Click "Set password"

**Security Note:**
In Week 3, we'll manipulate SAML assertions to escalate alice → bob privileges. Understanding user differences now is critical.

### 1.4 Configure User Attributes

**Add custom attribute to Bob (for later privilege testing):**
1. Edit bob's profile
2. Go to "Attributes" tab
3. Add attribute:
   - Key: `role`
   - Value: `admin`
4. Click "Save"

**Add custom attribute to Alice:**
1. Edit alice's profile
2. Go to "Attributes" tab
3. Add attribute:
   - Key: `role`
   - Value: `user`
4. Click "Save"

**Why custom attributes?**
SAML assertions carry these attributes to the SP. In Week 3, we'll attempt to modify alice's role from "user" to "admin" via XML manipulation attacks.

---

## Step 2: SAML Client Configuration

### 2.1 Create SAML Client

**Navigate to:** Clients → Create client

**Settings:**
- Client type: `SAML`
- Client ID: `http://sp1.homelab.local:8081`
  - **Note:** This is the SP's EntityID, must match exactly
- Name: `SimpleSAMLphp SP`
- Description: `Test service provider for SAML learning`
- Click "Save"

### 2.2 Configure Client Settings

**Settings Tab:**
- Valid redirect URIs: `http://sp1.homelab.local:8081/*`
  - **Security Note:** Wildcard acceptable for lab only
  - Production: specify exact callback URLs

**SAML Capabilities:**
- Name ID format: `username`
- Force POST binding: ON
- Include AuthnStatement: ON
- Sign documents: ON
- Sign assertions: ON
- Signature algorithm: `RSA_SHA256`
- SAML signature key name: `CERT_SUBJECT`
- Canonicalization method: `EXCLUSIVE`

**Why sign both documents AND assertions?**
- Defense in depth against XML wrapping attacks
- We'll test this in Week 3 with XML Signature Wrapping (XSW)

### 2.3 Configure Assertion Consumer Service (ACS)

**Fine Grain SAML Endpoint Configuration:**
- Assertion Consumer Service POST Binding URL:
  ```
  http://sp1.homelab.local:8081/module.php/saml/sp/saml2-acs.php/default-sp
  ```

**Security Consideration:**
This URL receives the SAML assertion after authentication. In Week 3, we'll test if the SP validates the `Recipient` attribute matches this URL.

### 2.4 Configure Attribute Mappings

**Navigate to:** Client scopes → Dedicated scopes (for SimpleSAMLphp SP) → Add mapper

**Mapper 1: Username**
- Name: `username`
- Mapper type: `User Property`
- Property: `username`
- SAML Attribute Name: `uid`
- SAML Attribute NameFormat: `Basic`

**Mapper 2: Email**
- Name: `email`
- Mapper type: `User Property`
- Property: `email`
- SAML Attribute Name: `email`
- SAML Attribute NameFormat: `Basic`

**Mapper 3: First Name**
- Name: `firstName`
- Mapper type: `User Property`
- Property: `firstName`
- SAML Attribute Name: `givenName`
- SAML Attribute NameFormat: `Basic`

**Mapper 4: Last Name**
- Name: `lastName`
- Mapper type: `User Property`
- Property: `lastName`
- SAML Attribute Name: `sn`
- SAML Attribute NameFormat: `Basic`

**Mapper 5: Role (Custom Attribute)**
- Name: `role`
- Mapper type: `User Attribute`
- User Attribute: `role`
- SAML Attribute Name: `role`
- SAML Attribute NameFormat: `Basic`

**Attack Surface Analysis:**
These attributes are transmitted in the SAML assertion. In Week 3, we'll attempt to:
- Change alice's role from "user" to "admin"
- Modify email to gain access to different accounts
- Test if SP validates attribute signatures

---

## Step 3: Download IdP Metadata

The IdP metadata contains the public certificate and endpoint URLs needed by the SP.

### 3.1 Download Metadata XML

**Method 1: Browser**
```
http://localhost:8180/realms/homelab/protocol/saml/descriptor
```
Save as: `keycloak-idp-metadata.xml`

**Method 2: Command Line**
```bash
curl http://localhost:8180/realms/homelab/protocol/saml/descriptor \
  -o /home/ssjlox/AI/saml-lab/keycloak-idp-metadata.xml
```

### 3.2 Analyze Metadata (Security Review)

Key elements to examine:

**1. Signing Certificate:**
```xml
<md:KeyDescriptor use="signing">
  <ds:X509Certificate>...</ds:X509Certificate>
</md:KeyDescriptor>
```
- Used to verify SAML assertion signatures
- In Week 2: we'll verify this certificate is properly validated
- In Week 3: we'll test unsigned assertions (should be rejected)

**2. SSO Service Endpoint:**
```xml
<md:SingleSignOnService
  Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
  Location="http://localhost:8180/realms/homelab/protocol/saml"/>
```
- Where the SP redirects users for authentication

**3. Signature Algorithm:**
```xml
<ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
```
- SHA256 (secure) vs SHA1 (deprecated, vulnerable)
- Best practice: RSA-SHA256 minimum

---

## Step 4: Configure SimpleSAMLphp Service Provider

### 4.1 Copy IdP Metadata to Container

```bash
docker cp /home/ssjlox/AI/saml-lab/keycloak-idp-metadata.xml \
  saml-sp-simple:/var/simplesamlphp/metadata/keycloak-idp-metadata.xml
```

### 4.2 Configure Authentication Source

**Edit authsources.php:**

```bash
docker exec -it saml-sp-simple vi /var/simplesamlphp/config/authsources.php
```

**Add SAML configuration:**

```php
'default-sp' => [
    'saml:SP',

    'entityID' => 'http://sp1.homelab.local:8081',

    'idp' => 'http://localhost:8180/realms/homelab',

    'metadata.sign.enable' => true,
    'redirect.sign' => true,
    'assertion.encryption' => false,

    // Signature validation
    'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
    'validate.authnrequest' => true,
    'validate.logout' => true,
],
```

**Security Configuration Explained:**

- `metadata.sign.enable` → Sign SP metadata (prevents tampering)
- `redirect.sign` → Sign AuthnRequest (prevents request forgery)
- `assertion.encryption = false` → Easier to analyze in Week 2 (enable in production!)
- `validate.authnrequest` → Validates incoming requests
- `signature.algorithm` → SHA256 (secure)

**Week 3 Preview:** We'll test if disabling `redirect.sign` allows AuthnRequest manipulation.

### 4.3 Configure IdP Metadata

**Edit saml20-idp-remote.php:**

```bash
docker exec -it saml-sp-simple vi /var/simplesamlphp/metadata/saml20-idp-remote.php
```

**Add:**

```php
$metadata['http://localhost:8180/realms/homelab'] = [
    'metadata-set' => 'saml20-idp-remote',
    'SingleSignOnService' => [
        [
            'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
            'Location' => 'http://localhost:8180/realms/homelab/protocol/saml',
        ],
        [
            'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST',
            'Location' => 'http://localhost:8180/realms/homelab/protocol/saml',
        ],
    ],
    'SingleLogoutService' => [
        [
            'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
            'Location' => 'http://localhost:8180/realms/homelab/protocol/saml',
        ],
    ],
    'certData' => 'PASTE_CERTIFICATE_HERE',
    'sign.authnrequest' => true,
    'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
];
```

**Extract certificate from metadata:**

```bash
grep -oP '<ds:X509Certificate>\K[^<]+' keycloak-idp-metadata.xml
```

Paste the output into `certData` field.

---

## Step 5: Test SAML Authentication

### 5.1 Access SimpleSAMLphp

**URL:** http://sp1.homelab.local:8081 (or http://localhost:8081)

Click: **Authentication** → **Test configured authentication sources** → **default-sp**

### 5.2 Expected SAML Flow

**Step 1: SP generates AuthnRequest**
```xml
<samlp:AuthnRequest
  ID="_abc123"
  IssueInstant="2025-11-01T20:00:00Z"
  Destination="http://localhost:8180/realms/homelab/protocol/saml"
  AssertionConsumerServiceURL="http://sp1.homelab.local:8081/module.php/saml/sp/saml2-acs.php/default-sp">
  <saml:Issuer>http://sp1.homelab.local:8081</saml:Issuer>
</samlp:AuthnRequest>
```

**Step 2: Browser redirects to Keycloak**

**Step 3: User logs in (alice / alice123)**

**Step 4: Keycloak generates SAML Response**
```xml
<samlp:Response ID="_xyz789" InResponseTo="_abc123">
  <saml:Assertion>
    <saml:Subject>
      <saml:NameID>alice</saml:NameID>
    </saml:Subject>
    <saml:AttributeStatement>
      <saml:Attribute Name="uid"><saml:AttributeValue>alice</saml:AttributeValue></saml:Attribute>
      <saml:Attribute Name="email"><saml:AttributeValue>alice@homelab.local</saml:AttributeValue></saml:Attribute>
      <saml:Attribute Name="role"><saml:AttributeValue>user</saml:AttributeValue></saml:Attribute>
    </saml:AttributeStatement>
    <ds:Signature>...</ds:Signature>
  </saml:Assertion>
</samlp:Response>
```

**Step 5: Browser POSTs Response to SP**

**Step 6: SP validates signature and grants access**

### 5.3 Success Criteria

✅ Redirected to Keycloak login page
✅ After login, redirected back to SimpleSAMLphp
✅ Attributes displayed:
- uid: alice
- email: alice@homelab.local
- givenName: Alice
- sn: Anderson
- role: user

**If successful:** Week 1 Day 1 complete! You now understand the basic SAML flow.

**If errors occur:** Document the error message for troubleshooting.

---

## Security Analysis Checkpoints

### Checkpoint 1: Assertion Lifetime
After successful login, note the timestamp in the assertion:
- `NotBefore`: When assertion becomes valid
- `NotOnOrAfter`: When assertion expires

**Question for Week 2:** What happens if we replay an expired assertion?

### Checkpoint 2: Signature Coverage
Examine what's signed:
- Entire `<Response>` element?
- Just the `<Assertion>` element?
- Both?

**Question for Week 3:** If only assertion is signed, can we wrap it in a different response?

### Checkpoint 3: Attribute Trust
The SP trusts these attributes from the IdP:
- username
- email
- role

**Question for Week 3:** Can we modify these attributes before the SP sees them?

---

## Week 1 Day 1 Deliverables

1. ✅ Keycloak realm "homelab" created
2. ✅ Test users alice & bob created with role attributes
3. ✅ SAML client configured in Keycloak
4. ✅ SimpleSAMLphp configured with IdP metadata
5. ✅ Successful SAML authentication test
6. 📸 Screenshot of attribute display after login

---

## Next Steps (Week 1 Day 2)

1. **Install SAML Tracer browser extension**
   - Capture full SAML flow
   - Analyze AuthnRequest structure
   - Analyze SAML Response/Assertion

2. **Decode SAML Assertions**
   - Base64 decode
   - Pretty-print XML
   - Identify signature elements

3. **Test Logout Flow**
   - Understand SingleLogoutService
   - Capture LogoutRequest/Response

4. **Document findings** in lab notebook

---

## Skills Developed (Week 1 Day 1)

✅ Keycloak administration
✅ SAML realm configuration
✅ User management & custom attributes
✅ SAML client creation
✅ Metadata exchange
✅ SP configuration (SimpleSAMLphp)
✅ Basic SAML flow understanding

**Career Alignment:**
- Identity & Access Management (IAM)
- Security configuration
- Authentication protocol knowledge
- Foundation for OSCP/OSWE web app testing

---

## Session Status

**Current Task:** Waiting for student to complete Keycloak configuration steps

**Next Instructor Action:** Guide through SAML Tracer installation and assertion analysis (Week 1 Day 2)

