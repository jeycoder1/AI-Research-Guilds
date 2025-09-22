# AIResearchGuilds

Guild-based smart contracts that organize AI researchers into specialized groups for collaborative research, resource pooling, and reward sharing.

## Features

- **Guild Creation**: Form specialized research guilds around AI domains
- **Collaborative Funding**: Pool resources for expensive research projects
- **Democratic Governance**: Members vote on research proposals and funding
- **Research Project Management**: Track projects from proposal to completion
- **Reward Distribution**: Share profits from successful research outcomes
- **Reputation System**: Build guild and individual reputation through contributions

## Supported Specializations

- Machine Learning
- Robotics  
- Neural Networks
- AI Safety
- Quantum AI

## Contract Functions

### Public Functions
- `initialize()` - Set up research specializations
- `create-guild(name, specialization)` - Create new research guild
- `join-guild(guild-id, initial-contribution)` - Join existing guild with funding
- `propose-research(guild-id, title, budget)` - Propose new research project
- `vote-on-research(research-id, approve)` - Vote on research proposals
- `approve-research(research-id)` - Approve research project (founder/lead)
- `submit-findings(research-id, findings-hash, reward-amount)` - Submit completed research

### Read-Only Functions
- `get-guild(guild-id)` - Get guild details and stats
- `get-member(guild-id, member)` - Get member information
- `get-research(research-id)` - Retrieve research project details
- `get-guild-count()` - Get total number of guilds
- `is-valid-specialization(specialization)` - Check specialization validity

## Usage Flow

1. Researchers create specialized guilds with `create-guild()`
2. Members join guilds and contribute funds using `join-guild()`
3. Members propose research projects with `propose-research()`
4. Guild members vote on proposals using `vote-on-research()`
5. Approved research is conducted and findings submitted with `submit-findings()`
6. Rewards are distributed back to the guild treasury

## Governance Model

- Guild founders and research leads have approval authority
- Members vote on research proposals
- Reputation increases with successful contributions
- Rewards are shared among guild members based on participation

## Testing

Run tests using Clarinet:
```bash
clarinet test