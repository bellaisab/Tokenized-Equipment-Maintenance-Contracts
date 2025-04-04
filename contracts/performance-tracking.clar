;; Performance Tracking Contract
;; Monitors equipment uptime and issues

(define-map equipment-performance
  { asset-id: uint, period: uint }
  {
    uptime-percentage: uint,
    downtime-hours: uint,
    issues-reported: uint,
    issues-resolved: uint,
    last-updated: uint
  }
)

(define-map issues
  { issue-id: (tuple (asset-id uint) (timestamp uint)) }
  {
    description: (string-ascii 500),
    severity: uint,  ;; 1-5 scale
    reported-by: principal,
    status: (string-ascii 20),  ;; "open", "in-progress", "resolved"
    resolution-notes: (optional (string-ascii 500)),
    resolution-timestamp: (optional uint)
  }
)

(define-read-only (get-asset-owner (asset-id uint))
  (contract-call? .asset-registration get-asset-owner asset-id)
)

(define-public (report-performance
    (asset-id uint)
    (period uint)
    (uptime-percentage uint)
    (downtime-hours uint)
    (issues-reported uint)
    (issues-resolved uint))
  (let
    (
      (asset-owner (get-asset-owner asset-id))
      (current-time (unwrap-panic (get-block-info? time u0)))
    )
    ;; Only service providers or asset owners can report performance
    (asserts! (is-eq tx-sender asset-owner) (err u403))

    (map-set equipment-performance
      { asset-id: asset-id, period: period }
      {
        uptime-percentage: uptime-percentage,
        downtime-hours: downtime-hours,
        issues-reported: issues-reported,
        issues-resolved: issues-resolved,
        last-updated: current-time
      }
    )
    (ok true)
  )
)

(define-public (report-issue
    (asset-id uint)
    (description (string-ascii 500))
    (severity uint))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time u0)))
      (issue-id (tuple (asset-id asset-id) (timestamp current-time)))
    )
    ;; Severity must be between 1 and 5
    (asserts! (and (>= severity u1) (<= severity u5)) (err u400))

    (map-set issues
      { issue-id: issue-id }
      {
        description: description,
        severity: severity,
        reported-by: tx-sender,
        status: "open",
        resolution-notes: none,
        resolution-timestamp: none
      }
    )
    (ok issue-id)
  )
)

(define-public (update-issue-status
    (issue-id (tuple (asset-id uint) (timestamp uint)))
    (status (string-ascii 20))
    (resolution-notes (optional (string-ascii 500))))
  (let
    (
      (issue (unwrap! (map-get? issues { issue-id: issue-id }) (err u404)))
      (asset-id (get asset-id issue-id))
      (asset-owner (get-asset-owner asset-id))
      (current-time (unwrap-panic (get-block-info? time u0)))
      (is-resolved (is-eq status "resolved"))
    )
    ;; Only asset owner can update issue status
    (asserts! (is-eq tx-sender asset-owner) (err u403))

    (map-set issues
      { issue-id: issue-id }
      (merge issue {
        status: status,
        resolution-notes: (if is-resolved resolution-notes none),
        resolution-timestamp: (if is-resolved (some current-time) none)
      })
    )
    (ok true)
  )
)

(define-read-only (get-performance (asset-id uint) (period uint))
  (map-get? equipment-performance { asset-id: asset-id, period: period })
)

(define-read-only (get-issue (issue-id (tuple (asset-id uint) (timestamp uint))))
  (map-get? issues { issue-id: issue-id })
)
