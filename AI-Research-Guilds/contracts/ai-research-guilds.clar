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

;; Initialize with research specializations
(define-public (initialize)
  (begin
    (map-set specializations { specialization: "machine-learning" } { active: true, guild-count: u0 })
    (map-set specializations { specialization: "robotics" } { active: true, guild-count: u0 })
    (map-set specializations { specialization: "neural-networks" } { active: true, guild-count: u0 })
    (map-set specializations { specialization: "ai-safety" } { active: true, guild-count: u0 })
    (map-set specializations { specialization: "quantum-ai" } { active: true, guild-count: u0 })
    (map-set specializations { specialization: "nlp" } { active: true, guild-count: u0 })
    (map-set specializations { specialization: "computer-vision" } { active: true, guild-count: u0 })
    (ok true)
  )
)

;; Create a new research guild
(define-public (create-guild (name (string-ascii 50)) (specialization (string-ascii 50)) (min-reputation uint))
  (let
    (
      (guild-id (+ (var-get guild-count) u1))
      (spec-check (unwrap! (map-get? specializations { specialization: specialization }) ERR-INVALID-PROPOSAL))
    )
    (asserts! (get active spec-check) ERR-INVALID-PROPOSAL)
    (asserts! (<= min-reputation u1000) ERR-INVALID-THRESHOLD)
    
    (map-set guilds
      { guild-id: guild-id }
      {
        name: name,
        specialization: specialization,
        founder: tx-sender,
        member-count: u1,
        total-funds: u0,
        reputation-score: u100,
        created-at: block-height,
        active: true,
        min-reputation-required: min-reputation
      }
    )
    
    (map-set guild-members
      { guild-id: guild-id, member: tx-sender }
      {
        contribution: u0,
        join-date: block-height,
        reputation: u100,
        active: true,
        research-completed: u0,
        last-activity: block-height
      }
    )
    
    (map-set specializations
      { specialization: specialization }
      (merge spec-check { guild-count: (+ (get guild-count spec-check) u1) })
    )
    
    (var-set guild-count guild-id)
    (ok guild-id)
  )
)

;; Join an existing guild
(define-public (join-guild (guild-id uint) (initial-contribution uint))
  (let
    (
      (guild (unwrap! (map-get? guilds { guild-id: guild-id }) ERR-GUILD-NOT-FOUND))
      (existing-member (map-get? guild-members { guild-id: guild-id, member: tx-sender }))
    )
    (asserts! (get active guild) ERR-GUILD-INACTIVE)
    (asserts! (is-none existing-member) ERR-ALREADY-MEMBER)
    (asserts! (>= u50 (get min-reputation-required guild)) ERR-NOT-AUTHORIZED)
    (asserts! (> initial-contribution u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? initial-contribution tx-sender (as-contract tx-sender)))
    
    (map-set guild-members
      { guild-id: guild-id, member: tx-sender }
      {
        contribution: initial-contribution,
        join-date: block-height,
        reputation: u50,
        active: true,
        research-completed: u0,
        last-activity: block-height
      }
    )
    
    (map-set guilds
      { guild-id: guild-id }
      (merge guild { 
        member-count: (+ (get member-count guild) u1),
        total-funds: (+ (get total-funds guild) initial-contribution)
      })
    )
    
    (ok true)
  )
)

;; Leave guild with partial refund
(define-public (leave-guild (guild-id uint))
  (let
    (
      (guild (unwrap! (map-get? guilds { guild-id: guild-id }) ERR-GUILD-NOT-FOUND))
      (member (unwrap! (map-get? guild-members { guild-id: guild-id, member: tx-sender }) ERR-NOT-MEMBER))
      (refund-amount (/ (get contribution member) u2)) ;; 50% refund
    )
    (asserts! (get active member) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq tx-sender (get founder guild))) ERR-NOT-AUTHORIZED)
    
    (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
    
    (map-set guild-members
      { guild-id: guild-id, member: tx-sender }
      (merge member { active: false })
    )
    
    (map-set guilds
      { guild-id: guild-id }
      (merge guild { 
        member-count: (- (get member-count guild) u1),
        total-funds: (- (get total-funds guild) refund-amount)
      })
    )
    
    (ok true)
  )
)

;; Deactivate guild (founder only)
(define-public (deactivate-guild (guild-id uint))
  (let
    (
      (guild (unwrap! (map-get? guilds { guild-id: guild-id }) ERR-GUILD-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get founder guild)) ERR-NOT-AUTHORIZED)
    
    (map-set guilds
      { guild-id: guild-id }
      (merge guild { active: false })
    )
    
    (ok true)
  )
)