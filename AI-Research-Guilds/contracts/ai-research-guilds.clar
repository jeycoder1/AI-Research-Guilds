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