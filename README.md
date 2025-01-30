# GuardianNet: Decentralized Insurance Collective

GuardianNet is a blockchain-based decentralized insurance platform built on the Stacks network that enables community-driven protection through mutual insurance pools. The platform allows participants to collectively protect each other by pooling resources and democratically deciding on incident payouts.

## Features

- **Decentralized Governance**: Community-driven decision making on incident claims
- **Validator Integration**: External validation of incidents through oracle contracts
- **Transparent Operations**: All rules, incident reports, and voting processes are publicly verifiable
- **Flexible Coverage**: Supports multiple incident types with customizable parameters
- **Democratic Voting**: Community-based approval system with configurable consensus thresholds
- **Scalable Pool**: Dynamic pool size that grows with participant contributions

## Technical Architecture

### Core Components

1. **Participant Management**
   - Registration system with minimum deposit requirements
   - Active status tracking
   - Deposit amount monitoring

2. **Incident Handling**
   - Structured incident reporting
   - Multi-stage verification process
   - Evidence requirements
   - Impact level assessment

3. **Voting Mechanism**
   - Time-bound voting periods
   - Consensus-based decision making
   - Automated payout processing

4. **Validator Integration**
   - External incident verification
   - Impact score assessment
   - Proof validation

### Smart Contract Constants

```clarity
entry-deposit: 0.1 STX  // Minimum participation requirement
ballot-duration: 7 days // Voting period for incidents
consensus-threshold: 66% // Required approval for payout
```

## Getting Started

### Prerequisites

- Stacks wallet with STX tokens
- Basic understanding of blockchain transactions
- Familiarity with Clarity smart contracts

### Participation Guide

1. **Joining the Network**
   ```clarity
   (contract-call? .guardian-net join-network)
   ```
   Requires minimum deposit of 0.1 STX

2. **Reporting an Incident**
   ```clarity
   (contract-call? .guardian-net report-incident
     payout-amount
     incident-type
     incident-proof
     validator-contract)
   ```

3. **Voting on Incidents**
   ```clarity
   (contract-call? .guardian-net cast-vote incident-id approve)
   ```

### Administrative Functions

1. **Setting Incident Rules**
   ```clarity
   (contract-call? .guardian-net set-incident-rules
     incident-type
     impact-floor
     impact-ceiling
     required-proof)
   ```

## Implementation Guide

### Validator Contract Integration

To integrate a custom validator, implement the validator-trait:

```clarity
(define-trait validator-trait
  (
    (verify-incident 
      (
        (string-ascii 50)  ;; incident type
        (list 10 (string-ascii 100))  ;; incident proof
      ) 
      (response 
        {
          valid: bool, 
          impact-score: uint
        } 
        uint
      )
    )
  )
)
```

### Network Statistics

Query network status using read-only functions:

```clarity
(contract-call? .guardian-net get-pool-balance)
(contract-call? .guardian-net get-participant-info user)
(contract-call? .guardian-net get-incident-info incident-id)
```

## Security Considerations

1. **Deposit Protection**
   - Funds are held in contract
   - Maximum payout limit of 50% of pool balance
   - Required validator verification

2. **Voting Security**
   - Time-locked voting periods
   - Consensus threshold requirements
   - One vote per participant

3. **Access Control**
   - Administrative functions restricted to contract owner
   - Participant verification for all actions
   - Double-registration prevention

## Error Handling

The contract includes comprehensive error handling:

- `err-unauthorized`: Access control violation
- `err-already-member`: Duplicate registration attempt
- `err-low-deposit`: Insufficient participation deposit
- `err-payout-exceeded`: Excessive payout request
- `err-verification-failed`: Failed validator verification
- `err-invalid-incident-type`: Unsupported incident type
- `err-invalid-impact-level`: Impact score out of range
- `err-missing-proof`: Insufficient incident evidence
- `err-invalid-incident-id`: Non-existent incident reference

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Support

For technical support or queries:
- Open an issue in the repository
- Join our community channels
- Review the technical documentation

## Acknowledgments

- Stacks blockchain community
- Clarity smart contract developers
- Decentralized insurance pioneers
