import { describe, it, expect, beforeEach, vi } from 'vitest';

// Mock the Clarity contract environment
const mockTxSender = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const mockCurrentTime = 1620000000;

const mockContract = {
  equipmentPerformance: new Map(),
  issues: new Map(),
  
  // Mock for asset-registration contract call
  getAssetOwner(assetId) {
    return mockTxSender; // For testing, assume tx-sender is always the asset owner
  },
  
  // Mock for block-info
  getBlockInfo() {
    return mockCurrentTime;
  },
  
  reportPerformance(assetId, period, uptimePercentage, downtimeHours, issuesReported, issuesResolved) {
    const key = `${assetId}-${period}`;
    
    this.equipmentPerformance.set(key, {
      uptimePercentage,
      downtimeHours,
      issuesReported,
      issuesResolved,
      lastUpdated: this.getBlockInfo()
    });
    
    return { ok: true };
  },
  
  reportIssue(assetId, description, severity) {
    if (severity < 1 || severity > 5) {
      return { err: 400 };
    }
    
    const timestamp = this.getBlockInfo();
    const issueId = `${assetId}-${timestamp}`;
    
    this.issues.set(issueId, {
      description,
      severity,
      reportedBy: mockTxSender,
      status: "open",
      resolutionNotes: null,
      resolutionTimestamp: null
    });
    
    return { ok: { assetId, timestamp } };
  },
  
  updateIssueStatus(issueId, status, resolutionNotes) {
    if (!this.issues.has(issueId)) {
      return { err: 404 };
    }
    
    const issue = this.issues.get(issueId);
    const isResolved = status === "resolved";
    
    this.issues.set(issueId, {
      ...issue,
      status,
      resolutionNotes: isResolved ? resolutionNotes : null,
      resolutionTimestamp: isResolved ? this.getBlockInfo() : null
    });
    
    return { ok: true };
  },
  
  getPerformance(assetId, period) {
    const key = `${assetId}-${period}`;
    return this.equipmentPerformance.get(key) || null;
  },
  
  getIssue(issueId) {
    return this.issues.get(issueId) || null;
  }
};

describe('Performance Tracking Contract', () => {
  beforeEach(() => {
    // Reset the contract state before each test
    mockContract.equipmentPerformance = new Map();
    mockContract.issues = new Map();
  });
  
  it('should report performance metrics', () => {
    const result = mockContract.reportPerformance(
        1, // assetId
        202104, // period (YYYYMM)
        98, // uptimePercentage
        15, // downtimeHours
        3, // issuesReported
        2 // issuesResolved
    );
    
    expect(result).toEqual({ ok: true });
    expect(mockContract.equipmentPerformance.size).toBe(1);
    expect(mockContract.equipmentPerformance.get('1-202104')).toEqual({
      uptimePercentage: 98,
      downtimeHours: 15,
      issuesReported: 3,
      issuesResolved: 2,
      lastUpdated: mockCurrentTime
    });
  });
  
  it('should report an issue', () => {
    const result = mockContract.reportIssue(
        1, // assetId
        'Unusual vibration in motor assembly',
        3 // severity
    );
    
    expect(result).toEqual({ ok: { assetId: 1, timestamp: mockCurrentTime } });
    expect(mockContract.issues.size).toBe(1);
    expect(mockContract.issues.get('1-1620000000')).toEqual({
      description: 'Unusual vibration in motor assembly',
      severity: 3,
      reportedBy: mockTxSender,
      status: "open",
      resolutionNotes: null,
      resolutionTimestamp: null
    });
  });
  
  it('should reject issues with invalid severity', () => {
    const result = mockContract.reportIssue(
        1,
        'Unusual vibration in motor assembly',
        6 // Invalid severity (> 5)
    );
    
    expect(result).toEqual({ err: 400 });
    expect(mockContract.issues.size).toBe(0);
  });
  
  it('should update issue status', () => {
    // First report an issue
    mockContract.reportIssue(
        1,
        'Unusual vibration in motor assembly',
        3
    );
    
    const issueId = '1-1620000000';
    const result = mockContract.updateIssueStatus(
        issueId,
        "resolved",
        "Replaced worn bearing in motor assembly"
    );
    
    expect(result).toEqual({ ok: true });
    expect(mockContract.issues.get(issueId)).toEqual({
      description: 'Unusual vibration in motor assembly',
      severity: 3,
      reportedBy: mockTxSender,
      status: "resolved",
      resolutionNotes: "Replaced worn bearing in motor assembly",
      resolutionTimestamp: mockCurrentTime
    });
  });
});
