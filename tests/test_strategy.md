# Test Strategy - Steri-Tek Smart SOF

## Testing Pyramid Overview

```
           /\
          /  \
         / UI \
        /______\
       /        \
      / Contract \
     /____________\
    /              \
   /   Integration  \
  /__________________\
 /                    \
/        Unit          \
/______________________\
```

## Layer 1: Unit Tests (Foundation)

### Python Services - PyTest
**Location**: `services/tests/unit/`
**Coverage Target**: 90%+
**Execution**: `pytest --cov=. --cov-report=term-missing`

#### Test Categories:
- **Business Rules**: `test_rules.py`
  - Dose range calculations
  - PPS validation logic  
  - Facility constraints
  - DEA workflow triggers

- **Data Models**: `test_models.py`
  - Pydantic model validation
  - Field constraints
  - Serialization/deserialization

- **Utilities**: `test_utils.py`
  - PDF coordinate mapping
  - Signature hash generation
  - Date/time calculations

#### Example Test Structure:
```python
# tests/unit/test_dose_validation.py
import pytest
from services.sof.business_rules import DoseValidator

class TestDoseValidation:
    def test_split_dose_calculation(self):
        """Test split dose format parsing and range calculation"""
        validator = DoseValidator()
        result = validator.calculate_range("10+10+5", is_validated=False)
        
        assert result.total_dose == 25
        assert result.low_range == 22.5  # -10%
        assert result.high_range == 27.5  # +10%
    
    def test_validated_pps_exact_range(self):
        """Test validated PPS requires exact dose"""
        validator = DoseValidator()
        
        with pytest.raises(ValidationError) as exc_info:
            validator.validate_range(
                pps_code="VAL001", 
                target_dose=25, 
                low_range=24, 
                high_range=26
            )
        
        assert "exact dose range" in str(exc_info.value)
```

### Frontend - Jest + React Testing Library
**Location**: `frontend/tests/unit/`
**Coverage Target**: 85%+
**Execution**: `npm run test:unit`

#### Test Categories:
- **Components**: Wizard steps, form validation, signature capture
- **Hooks**: Custom React hooks for form state, API calls
- **Utils**: Field validation, dose calculations, formatting

#### Example Test:
```javascript
// frontend/tests/unit/DoseRangeInput.test.tsx
import { render, screen, fireEvent } from '@testing-library/react'
import { DoseRangeInput } from '@/components/forms/DoseRangeInput'

describe('DoseRangeInput', () => {
  it('calculates range for R&D PPS codes', async () => {
    render(
      <DoseRangeInput 
        ppsCode="RD123" 
        targetDose="30" 
        onChange={jest.fn()} 
      />
    )
    
    expect(screen.getByDisplayValue('27')).toBeInTheDocument()
    expect(screen.getByDisplayValue('33')).toBeInTheDocument()
  })
})
```

## Layer 2: Integration Tests

### Database Integration
**Framework**: PyTest with test database
**Location**: `services/tests/integration/`

```python
# tests/integration/test_sof_repository.py
import pytest
from sqlalchemy import create_engine
from services.database import get_test_db
from services.sof.repository import SOFRepository

@pytest.fixture
def test_db():
    engine = create_engine("postgresql://test:test@localhost/sof_test")
    return get_test_db(engine)

class TestSOFRepository:
    def test_create_and_retrieve_sof(self, test_db):
        """Test full SOF lifecycle through repository"""
        repo = SOFRepository(test_db)
        
        sof_data = {
            "facility": "Fremont",
            "pps_code": "TEST123",
            "target_dose": "25",
            # ... full SOF data
        }
        
        created_sof = repo.create(sof_data)
        retrieved_sof = repo.get_by_id(created_sof.id)
        
        assert retrieved_sof.facility == "Fremont"
        assert retrieved_sof.status == "draft"
```

### API Integration Tests
**Framework**: FastAPI TestClient
**Location**: `services/tests/integration/`

```python
# tests/integration/test_sof_api.py
from fastapi.testclient import TestClient
from services.main import app

client = TestClient(app)

class TestSOFAPI:
    def test_create_sof_workflow(self):
        """Test complete SOF creation workflow"""
        # Create SOF
        response = client.post("/sofs", json={
            "facility": "Fremont",
            "pps_code": "TEST123",
            # ... complete SOF data
        })
        
        assert response.status_code == 201
        sof_id = response.json()["id"]
        
        # Validate SOF
        validate_response = client.post(f"/sofs/{sof_id}/validate")
        assert validate_response.json()["valid"] is True
        
        # Sign SOF
        sign_response = client.post(f"/sofs/{sof_id}/sign", json={
            "data": "base64_signature_data",
            "signer_name": "John Doe",
            "signer_title": "Quality Manager"
        })
        
        assert sign_response.status_code == 200
        assert sign_response.json()["status"] == "signed"
```

## Layer 3: Contract Tests

### OpenAPI Schema Validation - Schemathesis
**Location**: `services/tests/contract/`
**Execution**: `schemathesis run --base-url=http://localhost:8000 docs/openapi.yaml`

```python
# tests/contract/test_api_contract.py
import schemathesis
from hypothesis import settings

schema = schemathesis.from_path("docs/openapi.yaml")

@schema.parametrize()
@settings(max_examples=50)
def test_api_contract(case):
    """Fuzz test API endpoints against OpenAPI schema"""
    response = case.call()
    case.validate_response(response)
```

### Consumer-Driven Contract Tests
**Framework**: Pact (Python + JavaScript)
**Purpose**: Ensure frontend-backend API compatibility

```python
# tests/contract/test_sof_service_pact.py
from pact import Consumer, Provider

pact = Consumer('frontend').has_pact_with(Provider('sof-service'))

def test_get_sof_contract():
    """Contract test for SOF retrieval"""
    expected = {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "facility": "Fremont",
        "status": "draft"
    }
    
    pact.given('SOF exists with id 123e4567-e89b-12d3-a456-426614174000') \
        .upon_receiving('a request for SOF details') \
        .with_request('GET', '/sofs/123e4567-e89b-12d3-a456-426614174000') \
        .will_respond_with(200, body=expected)
```

## Layer 4: End-to-End Tests - Cypress

### Critical User Journeys
**Location**: `frontend/cypress/e2e/`
**Execution**: `npm run cypress:run`

#### Test Categories:

1. **Happy Path Workflows**
```javascript
// cypress/e2e/sof-creation-happy-path.cy.ts
describe('SOF Creation - Happy Path', () => {
  it('creates a complete standard SOF', () => {
    cy.visit('/sof/create')
    
    // Step 1: Facility
    cy.get('[data-testid="facility-fremont"]').click()
    cy.get('[data-testid="next-button"]').click()
    
    // Step 2: Company
    cy.get('[data-testid="company-name"]').type('ACME Pharmaceuticals')
    cy.get('[data-testid="contact-email"]').type('john@acme.com')
    cy.get('[data-testid="next-button"]').click()
    
    // ... continue through all 8 steps
    
    // Final verification
    cy.get('[data-testid="success-message"]').should('contain', 'SOF created successfully')
    cy.get('[data-testid="sof-id"]').should('exist')
  })
})
```

2. **DEA Workflow**
```javascript
// cypress/e2e/dea-controlled-substance.cy.ts
describe('DEA Controlled Substance Workflow', () => {
  it('handles controlled substance SOF with DEA requirements', () => {
    cy.createSOFWithControlledSubstance()
    
    // DEA step should appear
    cy.get('[data-testid="dea-step"]').should('be.visible')
    
    // Fill DEA information
    cy.get('[data-testid="dea-number"]').type('AB1234567')
    cy.get('[data-testid="cssr-uri"]').type('https://dea.gov/cssr/12345')
    cy.get('[data-testid="substance-schedule"]').select('II')
    
    // Verify compliance warnings
    cy.get('[data-testid="schedule-ii-warning"]').should('be.visible')
  })
})
```

3. **Error Handling**
```javascript
// cypress/e2e/error-handling.cy.ts
describe('Error Handling', () => {
  it('handles network errors gracefully', () => {
    cy.intercept('POST', '/api/sofs/*/validate', { forceNetworkError: true })
    
    cy.visit('/sof/create')
    cy.fillSOFForm()
    cy.get('[data-testid="validate-button"]').click()
    
    cy.get('[data-testid="network-error"]').should('contain', 'Connection error')
    cy.get('[data-testid="retry-button"]').should('be.visible')
  })
})
```

## Layer 5: Performance Tests - k6

### Load Testing Scenarios
**Location**: `tests/performance/`
**Target**: 500 concurrent users, <1s p95 response time

```javascript
// tests/performance/sof_creation_load.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 500 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  // Create SOF
  let sofData = {
    facility: 'Fremont',
    ppsCode: 'LOAD001',
    targetDose: '25',
    // ... complete SOF payload
  };
  
  let response = http.post(`${__ENV.BASE_URL}/sofs`, JSON.stringify(sofData), {
    headers: { 'Content-Type': 'application/json' },
  });
  
  check(response, {
    'SOF created successfully': (r) => r.status === 201,
    'Response time < 1s': (r) => r.timings.duration < 1000,
  });
  
  sleep(1);
}
```

### Stress Testing
```javascript
// tests/performance/stress_test.js
export let options = {
  stages: [
    { duration: '1m', target: 1000 },
    { duration: '5m', target: 1000 },
    { duration: '1m', target: 0 },
  ],
};

// Test system behavior under extreme load
```

## GxP Validation Testing

### IQ (Installation Qualification)
- **Purpose**: Verify system installation per specifications
- **Tests**: Infrastructure deployment, service connectivity, database schema
- **Documentation**: Installation test protocols and reports

### OQ (Operational Qualification)
- **Purpose**: Verify system operates within specified parameters
- **Tests**: All functional requirements, performance benchmarks, security controls
- **Documentation**: Operational test protocols with traceability matrix

```python
# tests/gxp/test_operational_qualification.py
class TestOperationalQualification:
    def test_req_001_facility_validation(self):
        """OQ-001: System shall validate facility selection"""
        # Maps to functional requirement FR-001
        response = self.client.post("/sofs", json={
            "facility": "InvalidFacility",
            # ... other data
        })
        
        assert response.status_code == 400
        assert "facility" in response.json()["errors"]
        # Document test execution with requirement traceability
```

### PQ (Performance Qualification)
- **Purpose**: Verify system performs in production environment
- **Tests**: End-to-end workflows, load testing, disaster recovery
- **Documentation**: Performance qualification protocols

## Test Data Management

### Test Data Sets
**Location**: `fixtures/`

```python
# fixtures/sof_test_data.py
VALID_SOF_STANDARD = {
    "facility": "Fremont",
    "pps_code": "STD001",
    "target_dose": "25",
    "dose_range_low": 22.5,
    "dose_range_high": 27.5,
    # ... complete valid SOF
}

VALID_SOF_DEA = {
    # ... SOF with DEA requirements
    "dea_data": {
        "dea_number": "AB1234567",
        "cssr_inbound_uri": "https://dea.gov/cssr/12345",
        "substance_schedule": "II"
    }
}

INVALID_SOF_CASES = [
    # Various invalid combinations for negative testing
]
```

### Test Database Seeding
```python
# tests/conftest.py
@pytest.fixture(scope="session")
def test_data():
    """Seed test database with consistent test data"""
    # Create PPS catalog entries
    # Create test users with different roles
    # Create reference SOFs for duplication tests
```

## Continuous Testing Strategy

### Pre-commit Hooks
- **Linting**: Black, Flake8, ESLint, Prettier
- **Unit Tests**: Fast unit tests only (<5 minutes)
- **Type Checking**: mypy, TypeScript compiler

### CI Pipeline Testing
1. **Lint & Unit Tests**: All services and frontend
2. **Integration Tests**: Database and API integration
3. **Contract Tests**: Schema validation and Pact verification
4. **Security Scanning**: Dependency vulnerabilities, SAST
5. **Performance Tests**: Basic load tests on PR
6. **E2E Tests**: Critical path scenarios

### Release Testing
1. **Full Regression**: Complete test suite execution
2. **Performance Validation**: Load testing with production-like data
3. **Security Penetration Testing**: OWASP Top 10, API security
4. **GxP Compliance Verification**: Audit trail and validation testing
5. **Disaster Recovery Testing**: Backup/restore procedures

## Test Metrics & Reporting

### Coverage Targets
- **Unit Tests**: 90% line coverage, 80% branch coverage
- **Integration Tests**: 100% API endpoint coverage
- **E2E Tests**: 100% critical user journey coverage

### Quality Gates
- **Build Failure Threshold**: Any test failure fails the build
- **Performance Regression**: >10% response time increase fails deployment
- **Security Vulnerability**: High/Critical vulnerabilities block release

### Test Reporting
- **Coverage Reports**: Codecov integration with PR comments
- **Performance Dashboards**: Grafana dashboards for test metrics
- **Compliance Reports**: Automated GxP validation report generation
