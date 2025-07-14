;; BTC Legacy Vault - Time-Locked Inheritance and Multi-Beneficiary Smart Contract

;; === Constants and Errors ===
(define-constant ERR_INVALID_LOCK_PERIOD (err u100))
(define-constant ERR_NO_BALANCE (err u101))
(define-constant ERR_VAULT_INACTIVE (err u102))
(define-constant ERR_NO_HEIR (err u103))
(define-constant ERR_NOT_HEIR (err u104))
(define-constant ERR_STILL_LOCKED (err u105))
(define-constant ERR_VAULT_NOT_FOUND (err u106))
(define-constant ERR_TRANSFER_FAILED (err u107))
(define-constant ERR_NOT_OWNER (err u108))
(define-constant ERR_INVALID_INDEX (err u109))
(define-constant ERR_INVALID_SHARES (err u110))

;; === Admin Variable ===
(define-data-var admin principal tx-sender)

;; === Vault Data Structure ===
(define-map vaults
  principal ;; owner
  {
    heirs: (list 5 {addr: principal, share: uint}),
    unlock-block: uint,
    balance: uint,
    active: bool
  })

;; === Helper Functions ===

;; Helper function to validate that shares add up to 100
(define-private (sum-shares (heirs (list 5 {addr: principal, share: uint})))
  (fold + (map get-share heirs) u0))

(define-private (get-share (heir {addr: principal, share: uint}))
  (get share heir))

;; Helper function to distribute inheritance to a single heir
(define-private (distribute-to-heir 
  (heir {addr: principal, share: uint}) 
  (context {total: uint, success: bool}))
  (if (get success context)
    (let (
      (amount (/ (* (get total context) (get share heir)) u100))
      (recipient (get addr heir)))
      (match (as-contract (stx-transfer? amount tx-sender recipient))
        success context
        error (merge context {success: false})))
    context))

;; === Public Functions ===

(define-public (create-vault 
  (heirs (list 5 {addr: principal, share: uint})) 
  (lock-period uint) 
  (amount uint))
  (let (
    (total-shares (sum-shares heirs)))
    (begin
      (asserts! (> lock-period u0) ERR_INVALID_LOCK_PERIOD)
      (asserts! (> amount u0) ERR_NO_BALANCE)
      (asserts! (> (len heirs) u0) ERR_NO_HEIR)
      (asserts! (is-eq total-shares u100) ERR_INVALID_SHARES)
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set vaults tx-sender {
        heirs: heirs,
        unlock-block: (+ stacks-block-height lock-period),
        balance: amount,
        active: true
      })
      (ok true))))

(define-public (signal-alive)
  (match (map-get? vaults tx-sender)
    vault
    (begin
      (map-set vaults tx-sender {
        heirs: (get heirs vault),
        unlock-block: (+ stacks-block-height u10000),
        balance: (get balance vault),
        active: true
      })
      (ok true))
    ERR_VAULT_NOT_FOUND))

(define-public (claim-inheritance (owner principal))
  (match (map-get? vaults owner)
    vault
    (begin
      (asserts! (get active vault) ERR_VAULT_INACTIVE)
      (asserts! (> stacks-block-height (get unlock-block vault)) ERR_STILL_LOCKED)
      (let (
        (total (get balance vault))
        (heirs (get heirs vault))
        (distribution-result (fold distribute-to-heir 
                                   heirs 
                                   {total: total, success: true})))
        (begin
          (asserts! (get success distribution-result) ERR_TRANSFER_FAILED)
          (map-delete vaults owner)
          (ok {distributed: total, heir-count: (len heirs)}))))
    ERR_VAULT_NOT_FOUND))

(define-public (cancel-vault)
  (match (map-get? vaults tx-sender)
    vault
    (begin
      (asserts! (get active vault) ERR_VAULT_INACTIVE)
      (let ((amount (get balance vault)))
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-delete vaults tx-sender)
        (ok amount)))
    ERR_VAULT_NOT_FOUND))

(define-public (deactivate-vault)
  (match (map-get? vaults tx-sender)
    vault
    (begin
      (map-set vaults tx-sender {
        heirs: (get heirs vault),
        unlock-block: (get unlock-block vault),
        balance: (get balance vault),
        active: false
      })
      (ok true))
    ERR_VAULT_NOT_FOUND))

(define-public (add-funds (amount uint))
  (match (map-get? vaults tx-sender)
    vault
    (begin
      (asserts! (get active vault) ERR_VAULT_INACTIVE)
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set vaults tx-sender {
        heirs: (get heirs vault),
        unlock-block: (get unlock-block vault),
        balance: (+ (get balance vault) amount),
        active: (get active vault)
      })
      (ok (+ (get balance vault) amount)))
    ERR_VAULT_NOT_FOUND))

(define-public (update-heirs (new-heirs (list 5 {addr: principal, share: uint})))
  (let (
    (total-shares (sum-shares new-heirs)))
    (match (map-get? vaults tx-sender)
      vault
      (begin
        (asserts! (get active vault) ERR_VAULT_INACTIVE)
        (asserts! (> (len new-heirs) u0) ERR_NO_HEIR)
        (asserts! (is-eq total-shares u100) ERR_INVALID_SHARES)
        (map-set vaults tx-sender {
          heirs: new-heirs,
          unlock-block: (get unlock-block vault),
          balance: (get balance vault),
          active: (get active vault)
        })
        (ok true))
      ERR_VAULT_NOT_FOUND)))

(define-public (extend-lock-period (additional-blocks uint))
  (match (map-get? vaults tx-sender)
    vault
    (begin
      (asserts! (get active vault) ERR_VAULT_INACTIVE)
      (asserts! (> additional-blocks u0) ERR_INVALID_LOCK_PERIOD)
      (map-set vaults tx-sender {
        heirs: (get heirs vault),
        unlock-block: (+ (get unlock-block vault) additional-blocks),
        balance: (get balance vault),
        active: (get active vault)
      })
      (ok (+ (get unlock-block vault) additional-blocks)))
    ERR_VAULT_NOT_FOUND))

;; === Read-Only Functions ===

(define-read-only (get-vault (owner principal))
  (map-get? vaults owner))

(define-read-only (get-vault-status (owner principal))
  (match (map-get? vaults owner)
    vault
    (ok {
      active: (get active vault),
      heir-count: (len (get heirs vault)),
      blocks-until-unlock: (if (> (get unlock-block vault) stacks-block-height)
                            (- (get unlock-block vault) stacks-block-height)
                            u0),
      balance: (get balance vault),
      unlock-block: (get unlock-block vault)
    })
    ERR_VAULT_NOT_FOUND))

(define-read-only (get-heir-info (owner principal) (heir-index uint))
  (match (map-get? vaults owner)
    vault
    (match (element-at? (get heirs vault) heir-index)
      heir (ok heir)
      ERR_INVALID_INDEX)
    ERR_VAULT_NOT_FOUND))

(define-read-only (calculate-heir-amount (owner principal) (heir-index uint))
  (match (map-get? vaults owner)
    vault
    (match (element-at? (get heirs vault) heir-index)
      heir (ok (/ (* (get balance vault) (get share heir)) u100))
      ERR_INVALID_INDEX)
    ERR_VAULT_NOT_FOUND))

(define-read-only (get-admin)
  (ok (var-get admin)))

(define-read-only (is-vault-unlocked (owner principal))
  (match (map-get? vaults owner)
    vault
    (ok (> stacks-block-height (get unlock-block vault)))
    ERR_VAULT_NOT_FOUND))

(define-read-only (validate-heir-shares (heirs (list 5 {addr: principal, share: uint})))
  (ok (is-eq (sum-shares heirs) u100)))

;; === Admin Functions ===

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_OWNER)
    (var-set admin new-admin)
    (ok true)))

;; Emergency function to help with stuck vaults (admin only)
(define-public (emergency-unlock (owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_OWNER)
    (match (map-get? vaults owner)
      vault
      (begin
        (map-set vaults owner {
          heirs: (get heirs vault),
          unlock-block: stacks-block-height,
          balance: (get balance vault),
          active: (get active vault)
        })
        (ok true))
      ERR_VAULT_NOT_FOUND)))
