# GitGig - Decentralized Web3 Job Board

## Overview
GitGig is a decentralized job board platform built on the Stacks blockchain, enabling secure and transparent Web3 job posting and hiring with built-in payment escrow functionality. The platform connects employers with talent while ensuring secure payment handling through smart contracts.

## Features
- **Decentralized Job Posting**: Post jobs with detailed descriptions and requirements
- **Secure Payment Escrow**: Automatic payment handling through smart contracts
- **Application Management**: Review and manage job applications
- **Skill Matching**: Define required skills for each position
- **Deadline Management**: Set and track job posting deadlines
- **Payment Protection**: Funds are held in escrow until job completion

## Technical Architecture

### Smart Contract Structure
The contract consists of three main data structures:
1. **Jobs Map**: Stores job posting details
2. **Applications Map**: Manages job applications
3. **JobCounter**: Tracks the total number of jobs posted

### Constants
```clarity
min-payment: u1000000 (1 STX)
max-payment: u1000000000 (1000 STX)
min-deadline: u1440 (~10 days in blocks)
```

### Error Codes
- `err-owner-only (u100)`: Unauthorized access
- `err-not-found (u101)`: Resource not found
- `err-invalid-job (u102)`: Invalid job status/parameters
- `err-already-applied (u103)`: Duplicate application
- `err-insufficient-funds (u104)`: Payment issues
- `err-invalid-input (u105)`: Invalid input parameters

## Usage Guide

### For Employers

#### Posting a Job
```clarity
(post-job 
    title
    description
    payment
    deadline
    required-skills)
```
Parameters:
- `title`: Job title (max 256 characters)
- `description`: Detailed job description (max 1024 characters)
- `payment`: Amount in microSTX (between 1-1000 STX)
- `deadline`: Block height deadline (minimum 1440 blocks from current)
- `required-skills`: List of required skills (max 10 skills)

Example:
```clarity
(post-job 
    u"Senior Smart Contract Developer"
    u"Looking for an experienced Clarity developer..."
    u5000000
    u54000
    (list u"Clarity" u"Stacks" u"Web3"))
```

#### Accepting Applications
```clarity
(accept-application job-id applicant)
```

#### Completing Jobs
```clarity
(complete-job job-id)
```

### For Job Seekers

#### Applying for a Job
```clarity
(apply-for-job job-id proposal)
```
Parameters:
- `job-id`: Unique job identifier
- `proposal`: Application proposal (max 1024 characters)

### Viewing Information

#### Get Job Details
```clarity
(get-job job-id)
```

#### Get Application Details
```clarity
(get-application job-id applicant)
```

## Security Features

### Input Validation
- String length validation for all text inputs
- Payment amount boundaries
- Deadline minimums
- Required skills list size validation

### Access Control
- Employer-only functions for job management
- Prevention of self-applications
- Status-based operation restrictions

### Payment Protection
- Automatic escrow on job posting
- Secure fund release on completion
- Payment amount validation

## Development Setup

### Prerequisites
- Clarity CLI tools
- Stacks blockchain local development environment
- Stacks wallet for testing

### Local Deployment
1. Clone the repository
2. Deploy the contract using Clarinet:
```bash
clarinet contract deploy gitgig
```

### Testing
Run the included test suite:
```bash
clarinet test
```

## Contract Interactions

### Using Stacks.js
```javascript
// Example: Posting a job
async function postJob(title, description, payment, deadline, skills) {
    const txOptions = {
        contractAddress: 'CONTRACT_ADDRESS',
        contractName: 'gitgig',
        functionName: 'post-job',
        functionArgs: [
            stringUtf8CV(title),
            stringUtf8CV(description),
            uintCV(payment),
            uintCV(deadline),
            listCV(skills.map(s => stringUtf8CV(s)))
        ],
        senderKey: 'PRIVATE_KEY',
        network: 'mainnet/testnet'
    };
    
    const transaction = await makeContractCall(txOptions);
    return transaction;
}
```

## Best Practices

### For Employers
1. Set reasonable deadlines for job postings
2. Provide detailed job descriptions
3. Specify clear skill requirements
4. Review applications promptly
5. Complete jobs and release payments in a timely manner

### For Applicants
1. Submit detailed proposals
2. Apply only to matching skill requirements
3. Check job deadlines before applying
4. Maintain communication through the application process

## Contributing
We welcome contributions! Please follow these steps:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request with detailed description