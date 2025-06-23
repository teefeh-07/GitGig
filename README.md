# GitGig - Decentralized Freelance Platform

GitGig is a decentralized freelance platform built on the Stacks blockchain that enables secure, trustless interactions between clients and freelancers.

## Features

### Core Functionality
- **User Registration**: Register as a freelancer, client, or both
- **Gig Management**: Create, browse, and apply to freelance gigs
- **Secure Payments**: Escrow-based payment system using STX tokens
- **Rating System**: Rate and review completed gigs
- **Reputation Tracking**: Build reputation through completed gigs and ratings

### Smart Contract Features
- **Escrow System**: Automatic payment release upon gig completion
- **Dispute Prevention**: Clear status tracking and validation
- **Transparent Reviews**: On-chain rating and review system
- **User Profiles**: Comprehensive user management with statistics

## Contract Functions

### Public Functions

#### User Management
- `register-user(username, user-type)` - Register a new user
- `get-user(user-address)` - Get user profile information
- `get-user-average-rating(user-address)` - Get user's average rating

#### Gig Management
- `create-gig(title, description, budget, deadline)` - Create a new gig
- `apply-to-gig(gig-id, proposal, proposed-budget)` - Apply to a gig
- `accept-freelancer(gig-id, freelancer)` - Accept a freelancer for a gig
- `get-gig(gig-id)` - Get gig details
- `get-application(gig-id, applicant)` - Get application details

#### Payment System
- `fund-escrow(gig-id)` - Fund escrow for accepted gig
- `complete-gig(gig-id)` - Complete gig and release payment
- `get-escrow(gig-id)` - Get escrow details

#### Rating System
- `rate-gig(gig-id, rating, review-text)` - Rate and review a completed gig
- `get-review(gig-id, reviewer)` - Get review details

## Gig Workflow

1. **Registration**: Both client and freelancer register on the platform
2. **Gig Creation**: Client creates a gig with title, description, budget, and deadline
3. **Application**: Freelancers apply with proposals and proposed budgets
4. **Selection**: Client accepts a freelancer for the gig
5. **Escrow**: Client funds the escrow with the agreed amount
6. **Completion**: Client marks the gig as completed, releasing payment to freelancer
7. **Rating**: Both parties can rate and review each other

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) - Stacks smart contract development tool
- [Node.js](https://nodejs.org/) - For running tests

### Installation

1. Clone the repository:
```bash
git clone https://github.com/teefeh-07/GitGig.git
cd GitGig
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

### Development

The main contract is located in `contracts/teefeh.clar` and tests are in `tests/teefeh_test.ts`.

To deploy to devnet:
```bash
clarinet integrate
```

## Contract Architecture

### Data Structures

- **Users**: Store user profiles with ratings and completion statistics
- **Gigs**: Store gig details, status, and payment information
- **Applications**: Store freelancer applications to gigs
- **Reviews**: Store ratings and reviews for completed gigs
- **Escrow**: Manage locked payments for active gigs

### Status Flow
- `status-open` (0): Gig is open for applications
- `status-in-progress` (1): Freelancer accepted, work in progress
- `status-completed` (2): Gig completed, payment released
- `status-cancelled` (3): Gig cancelled
- `status-disputed` (4): Gig in dispute (future feature)

## Security Features

- **Access Control**: Only authorized users can perform specific actions
- **Input Validation**: All inputs are validated for correctness
- **Escrow Protection**: Payments are locked until gig completion
- **Status Validation**: Strict status flow prevents invalid state transitions

## Testing

The test suite covers:
- User registration and validation
- Gig creation and application flow
- Complete payment workflow
- Error handling and edge cases
- Rating and review system

Run tests with:
```bash
clarinet test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is open source and available under the [MIT License](LICENSE).

## Future Enhancements

- Dispute resolution mechanism
- Multi-milestone payments
- Category-based gig filtering
- Advanced search functionality
- Integration with external payment methods
- Mobile application interface
