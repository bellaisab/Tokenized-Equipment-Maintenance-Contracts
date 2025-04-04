;; Service Agreement Contract
;; Defines maintenance terms and schedules

(define-data-var last-agreement-id uint u0)

(define-map service-agreements
  { agreement-id: uint }
  {
    asset-id: uint,
    service-provider: principal,
    asset-owner: principal,
    start-date: uint,
    end-date: uint,
    maintenance-frequency: uint,
    terms: (string-ascii 500),
    active: bool
  }
)

(define-map scheduled-maintenance
  { agreement-id: uint, scheduled-date: uint }
  {
    completed: bool,
    completion-date: (optional uint),
    notes: (string-ascii 500)
  }
)

;; Import asset registration contract functions
(define-read-only (get-asset-owner (asset-id uint))
  (contract-call? .asset-registration get-asset-owner asset-id)
)

(define-public (create-service-agreement
    (asset-id uint)
    (service-provider principal)
    (start-date uint)
    (end-date uint)
    (maintenance-frequency uint)
    (terms (string-ascii 500)))
  (let
    (
      (new-agreement-id (+ (var-get last-agreement-id) u1))
      (asset-owner (get-asset-owner asset-id))
    )
    ;; Only the asset owner can create a service agreement
    (asserts! (is-eq tx-sender asset-owner) (err u403))

    (var-set last-agreement-id new-agreement-id)
    (map-set service-agreements
      { agreement-id: new-agreement-id }
      {
        asset-id: asset-id,
        service-provider: service-provider,
        asset-owner: asset-owner,
        start-date: start-date,
        end-date: end-date,
        maintenance-frequency: maintenance-frequency,
        terms: terms,
        active: true
      }
    )
    (ok new-agreement-id)
  )
)

(define-public (schedule-maintenance
    (agreement-id uint)
    (scheduled-date uint))
  (let
    (
      (agreement (unwrap! (map-get? service-agreements { agreement-id: agreement-id }) (err u404)))
    )
    ;; Only the service provider can schedule maintenance
    (asserts! (is-eq tx-sender (get service-provider agreement)) (err u403))

    (map-set scheduled-maintenance
      { agreement-id: agreement-id, scheduled-date: scheduled-date }
      {
        completed: false,
        completion-date: none,
        notes: ""
      }
    )
    (ok true)
  )
)

(define-public (complete-maintenance
    (agreement-id uint)
    (scheduled-date uint)
    (completion-date uint)
    (notes (string-ascii 500)))
  (let
    (
      (agreement (unwrap! (map-get? service-agreements { agreement-id: agreement-id }) (err u404)))
      (maintenance (unwrap! (map-get? scheduled-maintenance { agreement-id: agreement-id, scheduled-date: scheduled-date }) (err u404)))
    )
    ;; Only the service provider can complete maintenance
    (asserts! (is-eq tx-sender (get service-provider agreement)) (err u403))

    (map-set scheduled-maintenance
      { agreement-id: agreement-id, scheduled-date: scheduled-date }
      {
        completed: true,
        completion-date: (some completion-date),
        notes: notes
      }
    )
    (ok true)
  )
)

(define-public (terminate-agreement (agreement-id uint))
  (let
    (
      (agreement (unwrap! (map-get? service-agreements { agreement-id: agreement-id }) (err u404)))
    )
    ;; Either the asset owner or service provider can terminate
    (asserts! (or
      (is-eq tx-sender (get asset-owner agreement))
      (is-eq tx-sender (get service-provider agreement))
    ) (err u403))

    (map-set service-agreements
      { agreement-id: agreement-id }
      (merge agreement { active: false })
    )
    (ok true)
  )
)

(define-read-only (get-service-agreement (agreement-id uint))
  (map-get? service-agreements { agreement-id: agreement-id })
)

(define-read-only (get-maintenance-record (agreement-id uint) (scheduled-date uint))
  (map-get? scheduled-maintenance { agreement-id: agreement-id, scheduled-date: scheduled-date })
)
