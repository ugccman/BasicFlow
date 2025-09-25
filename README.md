# BASICFLOW - Universal Basic Income Distribution

A blockchain-based UBI (Universal Basic Income) system for transparent, automated distribution of basic income to verified community members.
Addresses **UN SDG 1: No Poverty** through direct wealth redistribution.

---

## Features

* **Recipient Management**: Register, verify, and manage UBI recipients with KYC, dependency scoring, and verification levels.
* **Program Management**: Create and manage UBI programs with budgets, eligibility criteria, and region targeting.
* **Automated Claims**: Claim UBI on a monthly basis with eligibility checks, budget validation, and dependency-based scaling.
* **Community Verifiers**: Stake-based verifiers who validate recipient eligibility and maintain accuracy/reputation scores.
* **Funding Sources**: Contributions from individuals or organizations with tracking of preferred programs and recurring options.
* **Emergency Distributions**: Region-specific emergency relief triggered and governed through approval votes.
* **Transparency**: All distributions, contributions, and claims are tracked on-chain.

---

## Data Structures

* **ubi-recipients**: Registry of community members eligible for UBI.
* **ubi-programs**: Configuration and tracking of active UBI programs.
* **distribution-claims**: History of claims made by recipients.
* **community-verifiers**: Registry of staked verifiers with performance tracking.
* **funding-sources**: Contributions and funding preferences of donors.
* **emergency-distributions**: Special-purpose emergency aid programs.

---

## Key Constants

* **Periods**: Daily, Weekly, Monthly claim periods.
* **Verification Levels**: Unverified → Basic → Verified → Premium.
* **Stakes & Contributions**:

  * Verifier minimum stake: 50 STX
  * Minimum fund contribution: 1 STX

---

## Core Functions

### Recipient Management

* `register-recipient(kyc-hash, location-region, dependency-score)`
* `verify-recipient(recipient, verification-level)`

### Program Management

* `create-ubi-program(program-name, monthly-amount, target-region, eligibility-criteria, total-budget, duration-months, verification-required)`

### Distribution

* `claim-ubi(program-id)`

### Verifier Management

* `register-verifier(region-focus)`

### Funding

* `contribute-to-fund(amount, target-programs)`

### Read-Only Views

* `get-recipient-info(recipient)`
* `get-program-info(program-id)`
* `get-claim-info(claim-id)`
* `can-claim-ubi(recipient, program-id)`
* `get-platform-stats()`
* `calculate-claimable-amount(recipient, program-id)`

### Administration

* `pause-program(program-id)`

---

## Platform Stats

* Tracks **total recipients**, **total programs**, **distributed funds**, **claims count**, and **current distribution period**.

---

## Security & Governance

* **Error Codes** for invalid actions, insufficient funds, duplicate registrations, ineligible claims, etc.
* **Ownership & Permissions** enforced for program creation and pausing.
* **Verifier Stakes** ensure accountability and prevent abuse.

---

## Use Cases

* Direct community wealth redistribution.
* Targeted UBI programs (regional or demographic).
* Emergency relief distributions.
* Transparent donor-driven funding mechanisms.

---

## License

This project is open-source and can be adapted for blockchain-based social impact initiatives.
