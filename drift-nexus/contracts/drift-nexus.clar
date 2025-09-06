;; Drift Nexus Dynamic Asset Evolution Protocol
;; Comprehensive smart contract for cross-dimensional racing vehicle evolution with performance tracking

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-PILOT-NOT-FOUND (err u103))
(define-constant ERR-VEHICLE-NOT-FOUND (err u104))
(define-constant ERR-RACE-EXPIRED (err u105))
(define-constant ERR-INVALID-PERFORMANCE (err u106))
(define-constant ERR-UPGRADE-NOT-FOUND (err u107))
(define-constant ERR-EVOLUTION-FAILED (err u108))
(define-constant ERR-TELEMETRY-CORRUPTED (err u109))
(define-constant ERR-INSUFFICIENT-QUANTUM-FUEL (err u110))
(define-constant ERR-TRACK-TEMPLATE-NOT-FOUND (err u111))
(define-constant ERR-DIMENSION-BRIDGE-DISABLED (err u112))
(define-constant ERR-RACE-QUEUE-FULL (err u113))
(define-constant ERR-RACE-DATA-NOT-FOUND (err u114))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MINIMUM-PILOT-STAKE u1000000) ;; 1 DRIFT token
(define-constant BASE-RACE-FEE u100)
(define-constant PERFORMANCE-THRESHOLD u80)
(define-constant MAX-RACE-QUEUE-SIZE u1000)
(define-constant RACE-TIMEOUT u144) ;; blocks

;; Data variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var protocol-fee-rate uint u250) ;; 2.5%
(define-data-var total-racing-pilots uint u0)
(define-data-var total-races uint u0)
(define-data-var race-counter uint u0)
(define-data-var upgrade-counter uint u0)
(define-data-var dimension-bridge-enabled bool true)
(define-data-var quantum-pause bool false)

;; Data maps
(define-map racing-pilots
    principal
    {
        stake: uint,
        performance-score: uint,
        total-races-completed: uint,
        last-active: uint,
        quantum-earnings: uint,
        is-active: bool
    }
)

(define-map vehicle-configurations
    principal
    {
        customization-price: uint,
        allowed-mechanics: (list 50 principal),
        blocked-track-types: (list 20 (string-ascii 32)),
        auto-evolution: bool,
        upgrade-budget: uint,
        total-earned: uint
    }
)

(define-map race-queue
    uint
    {
        pilot: principal,
        vehicle-owner: principal,
        telemetry-hash: (buff 32),
        priority: uint,
        quantum-fuel-price: uint,
        race-expiry-block: uint,
        track-template-id: uint,
        cross-dimension-target: (optional (string-ascii 20)),
        evolution-nodes: (list 3 principal),
        is-completed: bool,
        upgrade-escrow-amount: uint
    }
)

(define-map track-templates
    uint
    {
        creator: principal,
        template-hash: (buff 32),
        environmental-conditions: (list 10 (string-ascii 100)),
        is-active: bool,
        usage-count: uint,
        fee-per-race: uint
    }
)

(define-map evolution-proofs
    {race-id: uint, node: principal}
    {
        proof-hash: (buff 32),
        timestamp: uint,
        quantum-fuel-used: uint,
        attestation-signature: (buff 65)
    }
)

(define-map upgrade-contracts
    uint
    {
        depositor: principal,
        amount: uint,
        race-id: uint,
        evolution-condition: (string-ascii 50),
        expiry-block: uint,
        is-released: bool
    }
)

(define-map pilot-performance
    principal
    {
        success-rate: uint,
        average-race-time: uint,
        telemetry-corruption-reports: uint,
        last-penalty: uint,
        consecutive-wins: uint
    }
)

(define-map dimension-bridges
    (string-ascii 20)
    {
        is-enabled: bool,
        bridge-contract: principal,
        minimum-fee: uint,
        success-rate: uint
    }
)

;; Authorization functions
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

;; Input validation functions
(define-private (validate-stake-amount (amount uint))
    (>= amount MINIMUM-PILOT-STAKE)
)

(define-private (validate-performance (score uint))
    (<= score u100)
)

(define-private (validate-priority (priority uint))
    (and (>= priority u1) (<= priority u10))
)

;; Utility functions
(define-private (min (a uint) (b uint))
    (if (< a b) a b)
)

(define-private (max (a uint) (b uint))
    (if (> a b) a b)
)

(define-private (is-evolution-node (node principal) (node-list (list 3 principal)))
    (is-some (index-of node-list node))
)

(define-private (select-evolution-nodes (priority uint))
    (list tx-sender tx-sender tx-sender) ;; Simplified selection
)

(define-private (get-current-quantum-fuel-price)
    u1000 ;; Simplified pricing
)

(define-private (update-pilot-performance (pilot principal) (success bool))
    (match (map-get? pilot-performance pilot)
        performance
        (let ((new-wins (if success (+ (get consecutive-wins performance) u1) u0))
              (new-rate (if success 
                          (min u100 (+ (get success-rate performance) u1))
                          (max u0 (- (get success-rate performance) u5)))))
            (map-set pilot-performance pilot
                (merge performance {
                    success-rate: new-rate,
                    consecutive-wins: new-wins
                }))
            true
        )
        false
    )
)

;; Admin functions
(define-public (set-protocol-fee-rate (new-rate uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-rate u1000) ERR-INVALID-INPUT)
        (ok (var-set protocol-fee-rate new-rate))
    )
)

(define-public (toggle-quantum-pause)
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (ok (var-set quantum-pause (not (var-get quantum-pause))))
    )
)

(define-public (update-dimension-bridge-status (dimension-name (string-ascii 20)) (enabled bool))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (match (map-get? dimension-bridges dimension-name)
            bridge-info 
            (ok (map-set dimension-bridges dimension-name
                (merge bridge-info {is-enabled: enabled})))
            ERR-INVALID-INPUT
        )
    )
)

;; Pilot management functions
(define-public (register-racing-pilot (stake-amount uint))
    (let ((current-block block-height))
        (begin
            (asserts! (not (var-get quantum-pause)) ERR-NOT-AUTHORIZED)
            (asserts! (validate-stake-amount stake-amount) ERR-INSUFFICIENT-QUANTUM-FUEL)
            (asserts! (is-none (map-get? racing-pilots tx-sender)) ERR-INVALID-INPUT)
            
            (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
            
            (map-set racing-pilots tx-sender {
                stake: stake-amount,
                performance-score: u100,
                total-races-completed: u0,
                last-active: current-block,
                quantum-earnings: u0,
                is-active: true
            })
            
            (map-set pilot-performance tx-sender {
                success-rate: u100,
                average-race-time: u0,
                telemetry-corruption-reports: u0,
                last-penalty: u0,
                consecutive-wins: u0
            })
            
            (var-set total-racing-pilots (+ (var-get total-racing-pilots) u1))
            (ok true)
        )
    )
)

(define-public (stake-additional-quantum-fuel (amount uint))
    (match (map-get? racing-pilots tx-sender)
        pilot-info
        (begin
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (ok (map-set racing-pilots tx-sender
                (merge pilot-info {stake: (+ (get stake pilot-info) amount)})))
        )
        ERR-PILOT-NOT-FOUND
    )
)

(define-public (update-vehicle-configuration 
    (price uint) 
    (mechanics (list 50 principal))
    (blocked-tracks (list 20 (string-ascii 32)))
    (auto-evolve bool)
    (budget uint))
    (begin
        (asserts! (not (var-get quantum-pause)) ERR-NOT-AUTHORIZED)
        (asserts! (<= price u100000) ERR-INVALID-INPUT)
        
        (ok (map-set vehicle-configurations tx-sender {
            customization-price: price,
            allowed-mechanics: mechanics,
            blocked-track-types: blocked-tracks,
            auto-evolution: auto-evolve,
            upgrade-budget: budget,
            total-earned: (default-to u0 (get total-earned 
                (map-get? vehicle-configurations tx-sender)))
        }))
    )
)

(define-public (queue-race
    (vehicle-owner principal)
    (telemetry-hash (buff 32))
    (priority uint)
    (track-template-id uint)
    (cross-dimension (optional (string-ascii 20)))
    (upgrade-escrow-amount uint))
    (let ((race-id (+ (var-get race-counter) u1))
          (race-expiry-block (+ block-height RACE-TIMEOUT))
          (selected-nodes (select-evolution-nodes priority)))
        (begin
            (asserts! (not (var-get quantum-pause)) ERR-NOT-AUTHORIZED)
            (asserts! (validate-priority priority) ERR-INVALID-INPUT)
            (asserts! (< (var-get race-counter) MAX-RACE-QUEUE-SIZE) ERR-RACE-QUEUE-FULL)
            
            ;; Handle upgrade escrow if amount > 0
            (if (> upgrade-escrow-amount u0)
                (try! (stx-transfer? upgrade-escrow-amount tx-sender (as-contract tx-sender)))
                true
            )
            
            (map-set race-queue race-id {
                pilot: tx-sender,
                vehicle-owner: vehicle-owner,
                telemetry-hash: telemetry-hash,
                priority: priority,
                quantum-fuel-price: (get-current-quantum-fuel-price),
                race-expiry-block: race-expiry-block,
                track-template-id: track-template-id,
                cross-dimension-target: cross-dimension,
                evolution-nodes: selected-nodes,
                is-completed: false,
                upgrade-escrow-amount: upgrade-escrow-amount
            })
            
            (var-set race-counter race-id)
            (var-set total-races (+ (var-get total-races) u1))
            (ok race-id)
        )
    )
)

(define-public (submit-evolution-proof
    (race-id uint)
    (proof-hash (buff 32))
    (quantum-fuel-used uint)
    (signature (buff 65)))
    (match (map-get? race-queue race-id)
        race-data
        (begin
            (asserts! (is-evolution-node tx-sender (get evolution-nodes race-data)) ERR-NOT-AUTHORIZED)
            (asserts! (not (get is-completed race-data)) ERR-EVOLUTION-FAILED)
            (asserts! (<= block-height (get race-expiry-block race-data)) ERR-RACE-EXPIRED)
            
            (map-set evolution-proofs {race-id: race-id, node: tx-sender} {
                proof-hash: proof-hash,
                timestamp: block-height,
                quantum-fuel-used: quantum-fuel-used,
                attestation-signature: signature
            })
            
            ;; Update pilot performance
            (update-pilot-performance (get pilot race-data) true)
            
            ;; Mark race as completed
            (map-set race-queue race-id
                (merge race-data {is-completed: true}))
            
            ;; Release upgrade escrow if applicable
            (if (> (get upgrade-escrow-amount race-data) u0)
                (try! (as-contract (stx-transfer? 
                    (get upgrade-escrow-amount race-data)
                    tx-sender
                    (get vehicle-owner race-data))))
                true
            )
            
            (ok true)
        )
        ERR-RACE-DATA-NOT-FOUND
    )
)

(define-public (create-track-template
    (template-hash (buff 32))
    (environmental-conditions (list 10 (string-ascii 100)))
    (fee-per-race uint))
    (let ((template-id (+ (var-get upgrade-counter) u1)))
        (begin
            (asserts! (not (var-get quantum-pause)) ERR-NOT-AUTHORIZED)
            (asserts! (<= fee-per-race u10000) ERR-INVALID-INPUT)
            
            (map-set track-templates template-id {
                creator: tx-sender,
                template-hash: template-hash,
                environmental-conditions: environmental-conditions,
                is-active: true,
                usage-count: u0,
                fee-per-race: fee-per-race
            })
            
            (var-set upgrade-counter template-id)
            (ok template-id)
        )
    )
)

(define-public (deposit-upgrade-escrow
    (amount uint)
    (race-id uint)
    (evolution-condition (string-ascii 50))
    (expiry-blocks uint))
    (let ((upgrade-id (+ (var-get upgrade-counter) u1))
          (expiry-block (+ block-height expiry-blocks)))
        (begin
            (asserts! (not (var-get quantum-pause)) ERR-NOT-AUTHORIZED)
            (asserts! (> amount u0) ERR-INVALID-INPUT)
            (asserts! (is-some (map-get? race-queue race-id)) ERR-RACE-DATA-NOT-FOUND)
            
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            
            (map-set upgrade-contracts upgrade-id {
                depositor: tx-sender,
                amount: amount,
                race-id: race-id,
                evolution-condition: evolution-condition,
                expiry-block: expiry-block,
                is-released: false
            })
            
            (var-set upgrade-counter upgrade-id)
            (ok upgrade-id)
        )
    )
)

(define-public (release-upgrade-escrow (upgrade-id uint))
    (match (map-get? upgrade-contracts upgrade-id)
        upgrade-data
        (match (map-get? race-queue (get race-id upgrade-data))
            race-data
            (begin
                (asserts! (get is-completed race-data) ERR-EVOLUTION-FAILED)
                (asserts! (not (get is-released upgrade-data)) ERR-INVALID-INPUT)
                (asserts! (<= block-height (get expiry-block upgrade-data)) ERR-RACE-EXPIRED)
                
                ;; Transfer funds to vehicle owner
                (try! (as-contract (stx-transfer? 
                    (get amount upgrade-data)
                    tx-sender
                    (get vehicle-owner race-data))))
                
                ;; Mark as released
                (map-set upgrade-contracts upgrade-id
                    (merge upgrade-data {is-released: true}))
                
                (ok true)
            )
            ERR-RACE-DATA-NOT-FOUND
        )
        ERR-UPGRADE-NOT-FOUND
    )
)

;; Read-only functions
(define-read-only (get-racing-pilot (pilot principal))
    (map-get? racing-pilots pilot)
)

(define-read-only (get-vehicle-configuration (owner principal))
    (map-get? vehicle-configurations owner)
)

(define-read-only (get-race-data (race-id uint))
    (map-get? race-queue race-id)
)

(define-read-only (get-pilot-performance (pilot principal))
    (map-get? pilot-performance pilot)
)

(define-read-only (get-track-template (template-id uint))
    (map-get? track-templates template-id)
)

(define-read-only (get-evolution-proof (race-id uint) (node principal))
    (map-get? evolution-proofs {race-id: race-id, node: node})
)

(define-read-only (get-upgrade-contract (upgrade-id uint))
    (map-get? upgrade-contracts upgrade-id)
)

(define-read-only (get-dimension-bridge (dimension-name (string-ascii 20)))
    (map-get? dimension-bridges dimension-name)
)

(define-read-only (get-protocol-stats)
    {
        total-racing-pilots: (var-get total-racing-pilots),
        total-races: (var-get total-races),
        protocol-fee-rate: (var-get protocol-fee-rate),
        quantum-pause: (var-get quantum-pause),
        dimension-bridge-enabled: (var-get dimension-bridge-enabled)
    }
)