# UX Specification - Steri-Tek Smart SOF

## Wizard Flow (8 Steps)

### Step 1: Facility Selection
- **Purpose**: Select processing location
- **Fields**: Facility (Fremont/Lewisville radio buttons)
- **Validation**: Required selection
- **Navigation**: Next enabled after selection

### Step 2: Company Information  
- **Purpose**: Customer identification and contact
- **Fields**: Company name, contact person, email, phone
- **Validation**: Email format, required fields
- **Auto-complete**: Recent company entries

### Step 3: Processing Specifications
- **Purpose**: PPS code and dose requirements
- **Fields**: PPS Code, Target Dose, Dose Range (Low/High)
- **Validation**: 
  - PPS format validation (3-10 alphanumeric)
  - Split dose format recognition ("10+10+5")
  - Dose range calculation based on PPS type
- **Help Text**: "±10% unless validated PPS"

### Step 4: Material Counts
- **Purpose**: Product details and quantities
- **Fields**: Product Name, Lot Number, Quantity, Packaging
- **Features**: 
  - Add/remove multiple materials
  - Bulk import from CSV
  - Lot number format validation

### Step 5: Materials & Environment
- **Purpose**: Environmental conditions
- **Fields**: Environmental Condition (Ambient/Frozen/Refrigerated)
- **Special Logic**: 
  - Lewisville + Frozen → Show freezer capacity notice
  - Environmental restrictions by facility

### Step 6: DEA Information (Conditional)
- **Purpose**: Controlled substance handling
- **Trigger**: If materials require DEA oversight
- **Fields**: DEA Number, CSSR Inbound URI, Substance Schedule
- **Validation**: DEA number format (2 letters + 7 digits)

### Step 7: Shipping & Turnaround
- **Purpose**: Service level and timing
- **Fields**: Turnaround (Standard/Expedited), Special Instructions
- **Pricing**: Show estimated costs and timelines

### Step 8: Sign & Review
- **Purpose**: Final review and electronic signature
- **Features**:
  - Comprehensive review of all entered data
  - Electronic signature capture
  - PDF preview generation
  - Download options (PDF/CSV)

## Design System

### Color Palette
- **Primary**: Steri-Tek Teal `#00838F`
- **Secondary**: Professional Grey `#4E5B60`
- **Success**: `#059669`
- **Warning**: `#D97706`
- **Error**: `#DC2626`
- **Background**: `#F9FAFB`

### Typography
- **Primary Font**: Inter (Google Fonts)
- **Headings**: Inter SemiBold
- **Body**: Inter Regular
- **Code**: JetBrains Mono

### Component Library

#### Buttons
```css
.btn-primary {
  background: #00838F;
  color: white;
  padding: 12px 24px;
  border-radius: 8px;
  font-weight: 500;
}

.btn-secondary {
  background: transparent;
  color: #4E5B60;
  border: 1px solid #D1D5DB;
  padding: 12px 24px;
  border-radius: 8px;
}
```

#### Form Fields
- **Height**: 44px minimum (touch-friendly)
- **Border Radius**: 6px
- **Border**: 1px solid #D1D5DB
- **Focus State**: 2px solid #00838F
- **Error State**: 2px solid #DC2626

## Micro-copy & Help Text

### Field-Specific Help
- **PPS Code**: "Customer-specific process code (3-10 characters, letters and numbers only)"
- **Target Dose**: "Enter single dose (e.g., '25') or split dose (e.g., '10+10+5')"
- **Dose Range**: "Automatically calculated: ±10% for R&D orders, exact range for validated PPS"
- **DEA Number**: "Format: 2 letters followed by 7 digits (e.g., AB1234567)"
- **Environmental Condition**: "Select based on product requirements and facility capabilities"

### Validation Messages
- **Required**: "This field is required"
- **Format Error**: "Please enter a valid [field type]"
- **PPS Invalid**: "PPS code must be 3-10 alphanumeric characters"
- **Dose Range**: "Dose range exceeds acceptable variance for this PPS type"
- **DEA Format**: "DEA number must be 2 letters followed by 7 digits"

### Progress Indicators
- **Step Completion**: "Step X of 8 completed"
- **Validation Status**: "✓ All fields valid" / "⚠ X fields need attention"
- **Save Status**: "Draft saved automatically" / "Saving..." / "Last saved at [time]"

## Accessibility (WCAG AA Compliance)

### Color Contrast
- **Text on Background**: 4.5:1 minimum ratio
- **Interactive Elements**: 3:1 minimum ratio
- **Focus Indicators**: 3:1 minimum ratio against adjacent colors

### Keyboard Navigation
- **Tab Order**: Logical sequence through form fields
- **Skip Links**: "Skip to main content" for screen readers
- **Focus Management**: Clear focus indicators, modal focus trapping

### Screen Reader Support
```html
<!-- Example field with proper ARIA -->
<label for="pps-code" id="pps-label">
  Processing Code (PPS)
</label>
<input 
  id="pps-code"
  name="ppsCode"
  aria-describedby="pps-help pps-error"
  aria-invalid="false"
  required
/>
<div id="pps-help" class="help-text">
  Customer-specific process code (3-10 characters)
</div>
<div id="pps-error" class="error-text" aria-live="polite">
  <!-- Error message appears here -->
</div>
```

### ARIA Labels
- **Form Sections**: `aria-labelledby` linking to section headings
- **Help Text**: `aria-describedby` linking inputs to help text
- **Error Messages**: `aria-live="polite"` for dynamic error announcements
- **Progress**: `aria-valuenow`, `aria-valuemin`, `aria-valuemax` for wizard progress

## Responsive Design

### Breakpoints
- **Mobile**: 320px - 767px
- **Tablet**: 768px - 1023px  
- **Desktop**: 1024px+

### Mobile Optimizations
- **Touch Targets**: Minimum 44px × 44px
- **Form Fields**: Full-width on mobile, stacked layout
- **Navigation**: Hamburger menu, swipe gestures for wizard steps
- **Signature**: Touch-optimized signature pad

### Tablet Optimizations
- **Layout**: 2-column forms where appropriate
- **Navigation**: Sidebar wizard navigation
- **Touch**: Hover states disabled, focus on touch interactions

## Error States & Edge Cases

### Network Errors
- **Offline**: "You're currently offline. Changes will be saved when connection is restored."
- **Timeout**: "Request timed out. Please try again."
- **Server Error**: "Something went wrong. Please refresh and try again."

### Validation Errors
- **Field-Level**: Inline error messages with specific guidance
- **Form-Level**: Summary of all errors at top of form
- **Cross-Field**: Validation between related fields (dose ranges, DEA requirements)

### Data Loss Prevention
- **Auto-Save**: Every 30 seconds, after field blur
- **Browser Close**: "You have unsaved changes. Are you sure you want to leave?"
- **Session Timeout**: Warning at 5 minutes, auto-save draft

## Performance Requirements

### Loading States
- **Initial Load**: Skeleton screens for form structure
- **Validation**: Spinner on submit buttons during validation
- **File Upload**: Progress bars for signature/document uploads
- **PDF Generation**: "Generating PDF..." with estimated time

### Optimization Targets
- **First Contentful Paint**: < 1.5 seconds
- **Largest Contentful Paint**: < 2.5 seconds
- **Cumulative Layout Shift**: < 0.1
- **First Input Delay**: < 100ms
