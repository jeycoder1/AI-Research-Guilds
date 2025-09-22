;; AIResearchGuilds - Organize AI researchers into collaborative guilds
;; Members pool resources, share findings, and split rewards

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-GUILD-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-MEMBER (err u102))
(define-constant ERR-NOT-MEMBER (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-INVALID-PROPOSAL (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-GUILD-INACTIVE (err u107))
(define-constant ERR-ALREADY-VOTED (err u108))
(define-constant ERR-INVALID-THRESHOLD (err u109))

(define-data-var guild-count uint u0)
(define-data-var research-count uint u0)
(define-data-var collaboration-count uint u0)
(define-data-var platform-fee uint u25) ;; 2.5% platform fee

(define-map guilds
  { guild-id: uint }
  {
    name: (string-ascii 50),
    specialization: (string-ascii 50),
    founder: principal,
    member-count: uint,
    total-funds: uint,
    reputation-score: uint,
    created-at: uint,
    active: bool,
    min-reputation-required: uint
  }
)

(define-map guild-members
  { guild-id: uint, member: principal }
  {
    contribution: uint,
    join-date: uint,
    reputation: uint,
    active: bool,
    research-completed: uint,
    last-activity: uint
  }
)

(define-map research-projects
  { research-id: uint }
  {
    title: (string-ascii 100),
    guild-id: uint,
    lead-researcher: principal,
    budget: uint,
    status: (string-ascii 20),
    findings-hash: (optional (buff 32)),
    reward-pool: uint,
    deadline: uint,
    approval-threshold: uint
  }
)

(define-map member-votes
  { research-id: uint, member: principal }
  { voted: bool, approved: bool }
)

(define-map specializations
  { specialization: (string-ascii 50) }
  { active: bool, guild-count: uint }
)

(define-map guild-collaborations
  { collaboration-id: uint }
  {
    guild-a: uint,
    guild-b: uint,
    project-title: (string-ascii 100),
    joint-budget: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map reputation-history
  { member: principal, guild-id: uint }
  {
    initial-reputation: uint,
    reputation-changes: (list 10 int),
    last-updated: uint
  }
)