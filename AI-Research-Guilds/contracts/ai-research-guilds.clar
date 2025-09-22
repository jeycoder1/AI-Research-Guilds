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
        created-at: stacks-block-height,
        active: true,
        min-reputation-required: min-reputation
      }
    )
    
    (map-set guild-members
      { guild-id: guild-id, member: tx-sender }
      {
        contribution: u0,
        join-date: stacks-block-height,
        reputation: u100,
        active: true,
        research-completed: u0,
        last-activity: stacks-block-height
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
        join-date: stacks-block-height,
        reputation: u50,
        active: true,
        research-completed: u0,
        last-activity: stacks-block-height
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

;; Propose research project with deadline
(define-public (propose-research 
  (guild-id uint)
  (title (string-ascii 100))
  (budget uint)
  (deadline uint)
  (approval-threshold uint))
  (let
    (
      (research-id (+ (var-get research-count) u1))
      (guild (unwrap! (map-get? guilds { guild-id: guild-id }) ERR-GUILD-NOT-FOUND))
      (member (unwrap! (map-get? guild-members { guild-id: guild-id, member: tx-sender }) ERR-NOT-MEMBER))
    )
    (asserts! (get active guild) ERR-GUILD-INACTIVE)
    (asserts! (get active member) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get total-funds guild) budget) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> deadline stacks-block-height) ERR-INVALID-PROPOSAL)
    (asserts! (and (>= approval-threshold u51) (<= approval-threshold u100)) ERR-INVALID-THRESHOLD)
    
    (map-set research-projects
      { research-id: research-id }
      {
        title: title,
        guild-id: guild-id,
        lead-researcher: tx-sender,
        budget: budget,
        status: "proposed",
        findings-hash: none,
        reward-pool: u0,
        deadline: deadline,
        approval-threshold: approval-threshold
      }
    )
    
    (var-set research-count research-id)
    (ok research-id)
  )
)

;; Vote on research proposal
(define-public (vote-on-research (research-id uint) (approve bool))
  (let
    (
      (research (unwrap! (map-get? research-projects { research-id: research-id }) ERR-INVALID-PROPOSAL))
      (member (unwrap! (map-get? guild-members { guild-id: (get guild-id research), member: tx-sender }) ERR-NOT-MEMBER))
      (existing-vote (map-get? member-votes { research-id: research-id, member: tx-sender }))
    )
    (asserts! (get active member) ERR-NOT-AUTHORIZED)
    (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
    (asserts! (is-eq (get status research) "proposed") ERR-INVALID-PROPOSAL)
    (asserts! (< stacks-block-height (get deadline research)) ERR-INVALID-PROPOSAL)
    
    (map-set member-votes
      { research-id: research-id, member: tx-sender }
      { voted: true, approved: approve }
    )
    
    ;; Update member activity
    (map-set guild-members
      { guild-id: (get guild-id research), member: tx-sender }
      (merge member { last-activity: stacks-block-height })
    )
    
    (ok true)
  )
)

;; Approve research project (simplified - in practice would need vote counting)
(define-public (approve-research (research-id uint))
  (let
    (
      (research (unwrap! (map-get? research-projects { research-id: research-id }) ERR-INVALID-PROPOSAL))
      (guild (unwrap! (map-get? guilds { guild-id: (get guild-id research) }) ERR-GUILD-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get founder guild)) 
                  (is-eq tx-sender (get lead-researcher research))) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status research) "proposed") ERR-INVALID-PROPOSAL)
    (asserts! (< stacks-block-height (get deadline research)) ERR-INVALID-PROPOSAL)
    
    (map-set research-projects
      { research-id: research-id }
      (merge research { status: "approved" })
    )
    
    (map-set guilds
      { guild-id: (get guild-id research) }
      (merge guild { total-funds: (- (get total-funds guild) (get budget research)) })
    )
    
    (ok true)
  )
)

;; Submit research findings with reward distribution
(define-public (submit-findings (research-id uint) (findings-hash (buff 32)) (reward-amount uint))
  (let
    (
      (research (unwrap! (map-get? research-projects { research-id: research-id }) ERR-INVALID-PROPOSAL))
      (guild (unwrap! (map-get? guilds { guild-id: (get guild-id research) }) ERR-GUILD-NOT-FOUND))
      (member (unwrap! (map-get? guild-members { guild-id: (get guild-id research), member: tx-sender }) ERR-NOT-MEMBER))
      (platform-fee-amount (/ (* reward-amount (var-get platform-fee)) u1000))
      (net-reward (- reward-amount platform-fee-amount))
    )
    (asserts! (is-eq tx-sender (get lead-researcher research)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status research) "approved") ERR-INVALID-PROPOSAL)
    (asserts! (> reward-amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? reward-amount tx-sender (as-contract tx-sender)))
    
    (map-set research-projects
      { research-id: research-id }
      (merge research { 
        status: "completed",
        findings-hash: (some findings-hash),
        reward-pool: net-reward
      })
    )
    
    (map-set guilds
      { guild-id: (get guild-id research) }
      (merge guild { 
        reputation-score: (+ (get reputation-score guild) u20),
        total-funds: (+ (get total-funds guild) net-reward)
      })
    )
    
    ;; Update lead researcher stats
    (map-set guild-members
      { guild-id: (get guild-id research), member: tx-sender }
      (merge member { 
        research-completed: (+ (get research-completed member) u1),
        reputation: (+ (get reputation member) u30),
        last-activity: stacks-block-height
      })
    )
    
    (ok true)
  )
)

;; Create inter-guild collaboration
(define-public (create-collaboration 
  (guild-a uint) 
  (guild-b uint) 
  (project-title (string-ascii 100)) 
  (joint-budget uint))
  (let
    (
      (collaboration-id (+ (var-get collaboration-count) u1))
      (guild-a-data (unwrap! (map-get? guilds { guild-id: guild-a }) ERR-GUILD-NOT-FOUND))
      (guild-b-data (unwrap! (map-get? guilds { guild-id: guild-b }) ERR-GUILD-NOT-FOUND))
      (member-a (unwrap! (map-get? guild-members { guild-id: guild-a, member: tx-sender }) ERR-NOT-MEMBER))
    )
    (asserts! (get active guild-a-data) ERR-GUILD-INACTIVE)
    (asserts! (get active guild-b-data) ERR-GUILD-INACTIVE)
    (asserts! (not (is-eq guild-a guild-b)) ERR-INVALID-PROPOSAL)
    (asserts! (get active member-a) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get reputation member-a) u100) ERR-NOT-AUTHORIZED)
    
    (map-set guild-collaborations
      { collaboration-id: collaboration-id }
      {
        guild-a: guild-a,
        guild-b: guild-b,
        project-title: project-title,
        joint-budget: joint-budget,
        status: "proposed",
        created-at: stacks-block-height
      }
    )
    
    (var-set collaboration-count collaboration-id)
    (ok collaboration-id)
  )
)

;; Update member reputation (guild founder or lead researcher only)
(define-public (update-member-reputation (guild-id uint) (member principal) (reputation-change int))
  (let
    (
      (guild (unwrap! (map-get? guilds { guild-id: guild-id }) ERR-GUILD-NOT-FOUND))
      (target-member (unwrap! (map-get? guild-members { guild-id: guild-id, member: member }) ERR-NOT-MEMBER))
      (new-reputation (+ (to-uint (+ (to-int (get reputation target-member)) reputation-change)) u0))
    )
    (asserts! (is-eq tx-sender (get founder guild)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= reputation-change -50) (<= reputation-change 100)) ERR-INVALID-AMOUNT)
    
    (map-set guild-members
      { guild-id: guild-id, member: member }
      (merge target-member { reputation: new-reputation })
    )
    
    (ok true)
  )
)

;; Distribute research rewards to guild members
(define-public (distribute-rewards (research-id uint))
  (let
    (
      (research (unwrap! (map-get? research-projects { research-id: research-id }) ERR-INVALID-PROPOSAL))
      (guild (unwrap! (map-get? guilds { guild-id: (get guild-id research) }) ERR-GUILD-NOT-FOUND))
      (reward-per-member (/ (get reward-pool research) (get member-count guild)))
    )
    (asserts! (is-eq (get status research) "completed") ERR-INVALID-PROPOSAL)
    (asserts! (is-eq tx-sender (get lead-researcher research)) ERR-NOT-AUTHORIZED)
    (asserts! (> (get reward-pool research) u0) ERR-INSUFFICIENT-FUNDS)
    
    ;; Simplified reward distribution - in practice would iterate through all members
    (try! (as-contract (stx-transfer? reward-per-member tx-sender (get lead-researcher research))))
    
    (map-set research-projects
      { research-id: research-id }
      (merge research { reward-pool: u0 })
    )
    
    (ok reward-per-member)
  )
)

;; Read-only functions
(define-read-only (get-guild (guild-id uint))
  (map-get? guilds { guild-id: guild-id })
)

(define-read-only (get-member (guild-id uint) (member principal))
  (map-get? guild-members { guild-id: guild-id, member: member })
)

(define-read-only (get-research (research-id uint))
  (map-get? research-projects { research-id: research-id })
)

(define-read-only (get-collaboration (collaboration-id uint))
  (map-get? guild-collaborations { collaboration-id: collaboration-id })
)

(define-read-only (get-guild-count)
  (var-get guild-count)
)

(define-read-only (get-research-count)
  (var-get research-count)
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-read-only (is-valid-specialization (specialization (string-ascii 50)))
  (default-to { active: false, guild-count: u0 } (map-get? specializations { specialization: specialization }))
)

(define-read-only (get-guild-by-specialization (specialization (string-ascii 50)))
  (map-get? specializations { specialization: specialization })
)

(define-read-only (calculate-member-share (guild-id uint) (member principal))
  (let
    (
      (guild (map-get? guilds { guild-id: guild-id }))
      (member-data (map-get? guild-members { guild-id: guild-id, member: member }))
    )
    (match guild
      guild-info (match member-data
        member-info (some (/ (* (get contribution member-info) u100) (get total-funds guild-info)))
        none)
      none)
  )
)