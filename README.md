# Bustoken - Public Bus Token System 🚌

A blockchain-based smart ticketing system for public transportation that tracks each ride with tamper-proof digital tokens.

## Overview

Bustoken is a decentralized public transportation payment system built on the Stacks blockchain. It provides a modern, secure, and transparent way to manage bus tickets, track rides, and handle payments using smart contracts.

## Features

### 🎫 Digital Ticket Management
- Purchase digital bus tokens with STX
- Unique ticket IDs for each transaction
- Real-time ticket validation and usage tracking
- Automatic expiry management

### 🚌 Ride Tracking System
- Complete ride history on blockchain
- Bus route and stop tracking
- Passenger journey analytics
- Immutable travel records

### 💰 Token Economy
- STX-based ticket pricing
- Dynamic pricing based on route distance
- Operator revenue distribution
- Transparent fee structure

### 👥 Multi-Role System
- **Passengers**: Purchase and use digital tickets
- **Bus Operators**: Validate tickets and manage routes
- **System Admin**: Configure pricing and manage operators
- **Inspectors**: Verify ticket validity

## Smart Contracts

### 1. Ticket Manager Contract (`ticket-manager.clar`)
Handles the core ticketing functionality:
- Ticket purchase and issuance
- Ticket validation and usage
- Pricing management
- Operator authorization

### 2. Ride Tracker Contract (`ride-tracker.clar`)
Manages ride-specific operations:
- Journey recording
- Route management
- Passenger analytics
- Revenue tracking

## Technology Stack

- **Blockchain**: Stacks (STX)
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet
- **Testing**: Vitest
- **Version Control**: Git

## Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- [Node.js](https://nodejs.org/) v16+
- Git

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Bustoken
```

2. Install dependencies:
```bash
npm install
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
npm test
```

## Usage

### For Passengers

1. **Purchase Ticket**: Buy digital tokens using STX
2. **Board Bus**: Present digital ticket for validation
3. **Complete Journey**: Ticket automatically processed at destination
4. **View History**: Access complete ride history

### For Bus Operators

1. **Route Setup**: Configure bus routes and stops
2. **Ticket Validation**: Scan and validate passenger tickets
3. **Revenue Tracking**: Monitor earnings and analytics
4. **Passenger Management**: Handle boarding and journey completion

### For System Administrators

1. **Pricing Management**: Set and update ticket prices
2. **Operator Authorization**: Approve new bus operators
3. **System Configuration**: Manage system parameters
4. **Revenue Distribution**: Handle operator payouts

## Contract Architecture

The system uses a two-contract architecture:

1. **Ticket Manager**: Core ticketing operations and token management
2. **Ride Tracker**: Journey tracking and analytics

This separation ensures:
- **Scalability**: Independent contract upgrades
- **Security**: Isolated functionality domains
- **Maintainability**: Clean code organization
- **Performance**: Optimized contract interactions

## Security Features

- **Authorization Controls**: Role-based access permissions
- **Ticket Validation**: Cryptographic ticket verification
- **Anti-Fraud**: Duplicate usage prevention
- **Audit Trail**: Complete transaction history
- **Secure Payments**: STX-based secure transactions

## Economic Model

### Ticket Pricing
- Base fare: Configurable per route
- Distance multiplier: Dynamic pricing
- Peak hour adjustments: Time-based pricing
- Bulk discounts: Multi-ticket purchases

### Revenue Distribution
- Operator share: Configurable percentage
- System maintenance: Platform fee
- Development fund: Future improvements
- Community rewards: User incentives

## Benefits

### For Passengers
- **Convenience**: Digital tickets on mobile devices
- **Transparency**: Clear pricing and journey tracking
- **Security**: Blockchain-secured transactions
- **History**: Complete travel record keeping

### for Operators
- **Efficiency**: Automated ticket validation
- **Analytics**: Detailed ridership data
- **Revenue**: Transparent earnings tracking
- **Management**: Streamlined operations

### For Cities
- **Data**: Real-time transportation analytics
- **Planning**: Evidence-based route optimization
- **Efficiency**: Reduced cash handling
- **Innovation**: Modern transit solutions

## Future Enhancements

- **Multi-Modal Integration**: Support for trains, trams, etc.
- **Loyalty Programs**: Reward frequent travelers
- **Dynamic Routing**: AI-powered route optimization
- **Carbon Credits**: Environmental impact tracking
- **Cross-City**: Inter-city travel integration

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For questions or support, please open an issue in the GitHub repository.

---

**🚌 Making public transportation smarter, one ride at a time.**
