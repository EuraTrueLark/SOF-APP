# Steri-Tek Smart SOF - AI-Coder Integration Kit

## 🚀 LLM-Ready Quick-Start Prompt

**You are an AI engineer tasked with building the Steri-Tek Smart SOF (Service Order Form) system.** This is a critical irradiation processing system that must meet GxP compliance requirements (21 CFR Part 11, ISO 13485, DEA regulations).

### Key Context:
- **Vision**: Zero-defect irradiation orders through AI-guided, self-validating workflows
- **Users**: Customer Planners, R&D Engineers, CSMs, Quality Auditors  
- **Constraints**: Must handle both standard and DEA-controlled substance workflows
- **Compliance**: 21 CFR Part 11 electronic signatures, ISO 13485 quality management

## 📋 Implementation Checklist

### Phase 1: Core Foundation
- [ ] **API Models**: Generate FastAPI routes and Pydantic models from `docs/openapi.yaml`
- [ ] **Database Schema**: Implement PostgreSQL schema from `docs/er.mmd`
- [ ] **Business Rules**: Implement dose validation logic from `tests/features/*.feature`
- [ ] **PDF Generation**: Create pdf-lib template loader using `docs/field_map.csv`

### Phase 2: Frontend Wizard
- [ ] **React Components**: 8-step wizard based on `docs/ux-specification.md`
- [ ] **Form Validation**: Real-time validation with business rules integration
- [ ] **Signature Capture**: Electronic signature component with SHA-256 hashing
- [ ] **Responsive Design**: Mobile-first approach with WCAG AA compliance

### Phase 3: Integration & Compliance
- [ ] **Authentication**: JWT-based auth with role-based access control
- [ ] **Audit Logging**: EventStore implementation for 21 CFR Part 11 compliance
- [ ] **File Storage**: S3-compatible storage with lifecycle management
- [ ] **DEA Workflow**: Conditional DEA fields and validation logic

## 🏗️ Architecture Quick Reference

```
Frontend (Next.js) → API Gateway (FastAPI) → Microservices
                          ↓
    PostgreSQL ← Business Logic → S3 Storage
                          ↓
                   EventStore (Audit)
```

### Service Endpoints
- **API Gateway**: `:8000` - Request routing, validation, rate limiting
- **SOF Service**: `:8001` - Business rules, PDF generation
- **Auth Service**: `:8002` - JWT authentication, RBAC
- **File Service**: `:8003` - Document storage, retrieval
- **Audit Service**: `:8004` - Compliance logging, event sourcing

## 📝 Key Implementation Patterns

### 1. SOF Creation Flow
```python
# Example: SOF creation with business rule validation
@router.post("/sofs", response_model=SOF)
async def create_sof(sof_data: SOFCreate, db: Session = Depends(get_db)):
    # Validate PPS code against catalog
    pps_entry = await validate_pps_code(sof_data.pps_code, db)
    
    # Apply dose range business rules
    dose_validator = DoseValidator()
    validated_ranges = dose_validator.calculate_range(
        target_dose=sof_data.target_dose,
        is_validated=pps_entry.is_validated
    )
    
    # Create SOF with validated data
    sof = SOF(**sof_data.dict(), **validated_ranges)
    db.add(sof)
    await db.commit()
    
    # Emit audit event
    await audit_service.log_event("sof.created", sof.id, user_id)
    
    return sof
```

### 2. Electronic Signature Implementation
```python
# 21 CFR Part 11 compliant signature handling
@router.post("/sofs/{sof_id}/sign")
async def sign_sof(sof_id: str, signature: SignatureData):
    # Generate SHA-256 hash for compliance
    signature_hash = hashlib.sha256(
        f"{signature.data}{signature.timestamp}{signature.signer_name}".encode()
    ).hexdigest()
    
    # Store signature with hash
    await signature_service.store_signature(sof_id, signature, signature_hash)
    
    # Generate PDF with embedded signature
    pdf_data = await pdf_service.generate_signed_pdf(sof_id, signature)
    
    # Audit trail for compliance
    await audit_service.log_signature_event(sof_id, signature_hash, user_id)
```

### 3. Business Rule Validation
```python
# Dose range validation based on PPS type
class DoseValidator:
    def calculate_range(self, target_dose: str, is_validated: bool) -> dict:
        # Parse split dose format (e.g., "10+10+5")
        if "+" in target_dose:
            doses = [float(d) for d in target_dose.split("+")]
            total_dose = sum(doses)
        else:
            total_dose = float(target_dose)
        
        if is_validated:
            # Validated PPS requires exact dose
            return {
                "dose_range_low": total_dose,
                "dose_range_high": total_dose
            }
        else:
            # R&D allows ±10% variance
            return {
                "dose_range_low": total_dose * 0.9,
                "dose_range_high": total_dose * 1.1
            }
```

## 🎯 Critical Success Metrics

### Performance Targets
- **First-Time-Right SOFs**: 97%
- **Median Completion Time**: ≤ 5 minutes
- **API Response Time**: p95 < 750ms
- **User Adoption**: > 90% within 6 months

### Quality Gates
- **Test Coverage**: 90% unit, 100% critical path E2E
- **PDF Generation**: Pixel-perfect accuracy with regression testing
- **Compliance**: 100% audit trail coverage for all SOF changes
- **Security**: Zero high/critical vulnerabilities

## 📚 Essential Files Reference

### Contract Specifications
- `docs/openapi.yaml` - Complete API specification with validation rules
- `docs/field_map.csv` - PDF field mapping for coordinate-based rendering
- `docs/glossary.csv` - Domain terminology and business definitions

### Business Logic
- `tests/features/*.feature` - BDD scenarios for all business rules
- `docs/compliance-matrix.md` - Regulatory requirements traceability
- `fixtures/*.json` - Complete test data examples

### Architecture
- `docs/system-architecture.md` - Service design and data flow
- `infra/gcp_cloudrun.tf` - Production infrastructure as code
- `.github/workflows/ci.yml` - Complete CI/CD pipeline

## 🛠️ Development Commands

```bash
# Backend Development
cd services
pip install -r requirements.txt
uvicorn main:app --reload --port 8000

# Frontend Development  
cd frontend
npm install
npm run dev

# Full Stack (Docker)
docker-compose up -d

# Testing
pytest --cov=. --cov-report=term-missing    # Backend tests
npm run test:unit                            # Frontend tests
npm run cypress:run                          # E2E tests

# Infrastructure
cd infra
terraform plan -var="environment=staging"
terraform apply
```

## 🔐 Security & Compliance Notes

### 21 CFR Part 11 Requirements
- **Electronic Signatures**: SHA-256 hash with timestamp and signer identity
- **Audit Trails**: Immutable event log for all SOF modifications
- **Access Controls**: Role-based permissions with strong authentication
- **Record Integrity**: Cryptographic verification of document authenticity

### Data Protection
- **Encryption**: AES-256 at rest, TLS 1.3 in transit
- **Access Logging**: All data access logged with user attribution
- **Retention**: 90-day draft retention, 7-year completed SOF retention
- **Backup**: Automated backups with tested recovery procedures

## 🚨 Common Implementation Pitfalls

1. **PDF Coordinate Mapping**: Ensure field coordinates are updated when PDF templates change
2. **Split Dose Parsing**: Handle complex dose formats like "10+10+5" correctly
3. **DEA Workflow**: DEA fields are conditional - only required for controlled substances
4. **Signature Compliance**: Must include signer name, timestamp, and hash in audit trail
5. **Facility Constraints**: Lewisville has freezer capacity limits, validate accordingly

## 📞 Success Validation

Your implementation is successful when:
- ✅ All BDD scenarios in `tests/features/` pass
- ✅ PDF generation matches expected output in `fixtures/expected.pdf`
- ✅ OpenAPI schema validation passes with no errors
- ✅ Cypress E2E tests complete the full 8-step wizard
- ✅ Performance tests meet <1s p95 response time target

## 🎯 Quick Win Implementation Order

1. **Start Here**: Implement SOF model from `docs/openapi.yaml`
2. **Business Logic**: Add dose validation from `tests/features/dose_validation.feature`
3. **PDF Generation**: Build template system using `docs/field_map.csv`
4. **Frontend**: Create wizard steps from `docs/ux-specification.md`
5. **Integration**: Connect all services with proper error handling
6. **Testing**: Validate against all fixture files and run full test suite

---

**Remember**: This system handles critical pharmaceutical processing - accuracy and compliance are non-negotiable. When in doubt, refer to the detailed specifications in the `/docs` directory and validate against the comprehensive test fixtures.
