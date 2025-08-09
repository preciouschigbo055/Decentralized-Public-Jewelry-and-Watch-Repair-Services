# Decentralized Public Jewelry and Watch Repair Services

A comprehensive blockchain-based system for managing jewelry and watch repair services, certifications, and insurance claims coordination.

## Overview

This system consists of five interconnected smart contracts that manage different aspects of the jewelry and watch repair industry:

1. **Jewelry Repair Certification Contract** - Issues and manages licenses for jewelry repair and custom jewelry making services
2. **Watch Repair Licensing Contract** - Handles permits for watch and clock repair specialists
3. **Precious Metals Handling Contract** - Regulates businesses working with gold, silver, and precious stones
4. **Appraisal Services Oversight Contract** - Manages licenses for jewelry appraisers and gemologists
5. **Insurance Claim Coordination Contract** - Facilitates jewelry repair and replacement for insurance claims

## Features

### Jewelry Repair Certification
- Issue repair technician licenses
- Track certification levels (Basic, Advanced, Master)
- Manage license renewals and expirations
- Fee collection and validation

### Watch Repair Licensing
- Specialized permits for watch repair
- Clock repair certifications
- Vintage timepiece specialist licenses
- Renewal tracking and notifications

### Precious Metals Handling
- Permits for gold/silver working
- Gemstone handling certifications
- Precious metals dealer licenses
- Compliance tracking

### Appraisal Services
- Certified appraiser licenses
- Gemologist certifications
- Insurance appraisal permits
- Quality assurance tracking

### Insurance Claim Coordination
- Claim registration and tracking
- Repair service matching
- Cost estimation validation
- Settlement coordination

## Contract Architecture

Each contract operates independently while maintaining consistent data structures and validation patterns. The system uses:

- **Principal-based access control** for secure operations
- **Time-based expiration** for licenses and permits
- **Fee-based validation** to ensure legitimate operations
- **Status tracking** for comprehensive oversight

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Basic understanding of Clarity smart contracts

### Installation

\`\`\`bash
git clone <repository-url>
cd jewelry-repair-services
npm install
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy
\`\`\`

## Usage Examples

### Issue a Jewelry Repair License

\`\`\`clarity
(contract-call? .jewelry-repair-certification issue-license
'SP1EXAMPLE...
"basic"
u365)
\`\`\`

### Register an Insurance Claim

\`\`\`clarity
(contract-call? .insurance-claim-coordination register-claim
"CLAIM-001"
u50000
"Ring repair needed")
\`\`\`

## License Structure

All licenses follow a consistent structure:
- **License ID**: Unique identifier
- **Holder**: Principal address of license holder
- **Type**: Category of license/permit
- **Issue Date**: Block height when issued
- **Expiration**: Block height when expires
- **Status**: Active, Expired, Suspended, Revoked
- **Fee Paid**: Amount paid for license

## Error Codes

- \`ERR-NOT-AUTHORIZED (u100)\`: Caller not authorized
- \`ERR-INVALID-LICENSE (u101)\`: License not found or invalid
- \`ERR-EXPIRED (u102)\`: License has expired
- \`ERR-INSUFFICIENT-PAYMENT (u103)\`: Payment amount too low
- \`ERR-ALREADY-EXISTS (u104)\`: License already exists
- \`ERR-INVALID-INPUT (u105)\`: Invalid input parameters

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Security Considerations

- All contracts use principal-based authentication
- Fee validation prevents spam transactions
- Time-based expiration ensures license validity
- Status tracking enables proper oversight

## Future Enhancements

- Cross-contract integration for comprehensive tracking
- Reputation scoring system
- Automated renewal notifications
- Integration with external insurance systems
