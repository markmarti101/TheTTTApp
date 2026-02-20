import { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import {
  getRequest,
  declineRequest,
  approveRequest,
  markRequestReviewed,
} from '../services/requests';
import { getTrainers } from '../services/trainers';
import type { CourseRequest } from '@training-triangle/shared';

export function RequestDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { profile } = useAuth();
  const [request, setRequest] = useState<(CourseRequest & { id: string }) | null>(null);
  const [trainers, setTrainers] = useState<{ id: string; email: string; displayName?: string }[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [declineReason, setDeclineReason] = useState('');
  const [trainerId, setTrainerId] = useState('');
  const [scheduledAt, setScheduledAt] = useState('');
  const [showDecline, setShowDecline] = useState(false);
  const [showApprove, setShowApprove] = useState(false);

  useEffect(() => {
    if (!id || !profile?.trainingCompanyId) {
      setLoading(false);
      return;
    }
    Promise.all([
      getRequest(id),
      getTrainers(profile.trainingCompanyId),
    ])
      .then(async ([req, trs]) => {
        setRequest(req ?? null);
        setTrainers(trs);
        if (trs.length > 0) setTrainerId(trs[0].id);
        if (req?.status === 'pending') {
          await markRequestReviewed(id);
          setRequest((prev: (CourseRequest & { id: string }) | null) =>
          prev ? { ...prev, status: 'reviewed' as const } : null
        );
        }
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [id, profile?.trainingCompanyId]);

  const handleDecline = async () => {
    if (!id || !declineReason.trim()) return;
    setActionLoading(true);
    try {
      await declineRequest(id, declineReason.trim());
      navigate('/requests');
    } catch (err) {
      console.error(err);
      alert('Failed to decline');
    } finally {
      setActionLoading(false);
    }
  };

  const handleApprove = async () => {
    if (!id || !trainerId || !scheduledAt) {
      alert('Please select a trainer and scheduled date');
      return;
    }
    setActionLoading(true);
    try {
      await approveRequest(id, trainerId, scheduledAt);
      navigate('/requests');
    } catch (err) {
      console.error(err);
      alert(err instanceof Error ? err.message : 'Failed to approve');
    } finally {
      setActionLoading(false);
    }
  };

  if (loading) return <div>Loading...</div>;
  if (!request) return <div>Request not found</div>;

  const canAct =
    (request.status === 'pending' || request.status === 'reviewed') &&
    profile?.trainingCompanyId === request.trainingCompanyId;

  return (
    <div>
      <div style={{ marginBottom: '1.5rem' }}>
        <Link to="/requests" style={{ color: 'var(--color-primary)' }}>
          ← Back to requests
        </Link>
      </div>
      <h2>{request.title}</h2>
      {request.topic && <p>Topic: {request.topic}</p>}
      <p>Status: <strong>{request.status}</strong></p>
      {request.preferredDates?.length && (
        <p>Preferred dates: {request.preferredDates.join(', ')}</p>
      )}
      {request.notes && <p>Notes: {request.notes}</p>}
      {request.declineReason && (
        <p style={{ color: '#dc2626' }}>Decline reason: {request.declineReason}</p>
      )}

      {canAct && (
        <div style={{ marginTop: '2rem' }}>
          {!showDecline && !showApprove && (
            <div style={{ display: 'flex', gap: '1rem' }}>
              <button
                onClick={() => setShowApprove(true)}
                style={{
                  padding: '0.5rem 1rem',
                  background: 'var(--color-primary)',
                  color: 'white',
                  border: 'none',
                  borderRadius: 4,
                  cursor: 'pointer',
                }}
              >
                Approve
              </button>
              <button
                onClick={() => setShowDecline(true)}
                style={{
                  padding: '0.5rem 1rem',
                  background: '#dc2626',
                  color: 'white',
                  border: 'none',
                  borderRadius: 4,
                  cursor: 'pointer',
                }}
              >
                Decline
              </button>
            </div>
          )}

          {showApprove && (
            <div
              style={{
                marginTop: '1rem',
                padding: '1rem',
                border: '1px solid var(--color-border)',
                borderRadius: 8,
                maxWidth: 400,
              }}
            >
              <h3>Approve & create course</h3>
              <div style={{ marginBottom: '1rem' }}>
                <label style={{ display: 'block', marginBottom: 4 }}>
                  Trainer
                </label>
                <select
                  value={trainerId}
                  onChange={(e) => setTrainerId(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.5rem',
                    border: '1px solid var(--color-border)',
                    borderRadius: 4,
                  }}
                >
                  {trainers.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.displayName || t.email}
                    </option>
                  ))}
                  {trainers.length === 0 && (
                    <option value="">No trainers — add trainer ID below</option>
                  )}
                </select>
                <input
                  type="text"
                  placeholder="Or type trainer ID"
                  value={trainerId}
                  onChange={(e) => setTrainerId(e.target.value)}
                  style={{
                    width: '100%',
                    marginTop: 8,
                    padding: '0.5rem',
                    border: '1px solid var(--color-border)',
                    borderRadius: 4,
                  }}
                />
              </div>
              <div style={{ marginBottom: '1rem' }}>
                <label style={{ display: 'block', marginBottom: 4 }}>
                  Scheduled date & time
                </label>
                <input
                  type="datetime-local"
                  value={scheduledAt}
                  onChange={(e) => setScheduledAt(e.target.value)}
                  required
                  style={{
                    width: '100%',
                    padding: '0.5rem',
                    border: '1px solid var(--color-border)',
                    borderRadius: 4,
                  }}
                />
              </div>
              <div style={{ display: 'flex', gap: '0.5rem' }}>
                <button
                  onClick={handleApprove}
                  disabled={actionLoading}
                  style={{
                    padding: '0.5rem 1rem',
                    background: 'var(--color-primary)',
                    color: 'white',
                    border: 'none',
                    borderRadius: 4,
                    cursor: actionLoading ? 'not-allowed' : 'pointer',
                  }}
                >
                  {actionLoading ? 'Creating...' : 'Create course'}
                </button>
                <button
                  onClick={() => setShowApprove(false)}
                  style={{
                    padding: '0.5rem 1rem',
                    background: 'transparent',
                    border: '1px solid var(--color-border)',
                    borderRadius: 4,
                    cursor: 'pointer',
                  }}
                >
                  Cancel
                </button>
              </div>
            </div>
          )}

          {showDecline && (
            <div
              style={{
                marginTop: '1rem',
                padding: '1rem',
                border: '1px solid var(--color-border)',
                borderRadius: 8,
                maxWidth: 400,
              }}
            >
              <h3>Decline request</h3>
              <div style={{ marginBottom: '1rem' }}>
                <label style={{ display: 'block', marginBottom: 4 }}>
                  Reason (required)
                </label>
                <textarea
                  value={declineReason}
                  onChange={(e) => setDeclineReason(e.target.value)}
                  placeholder="e.g. No availability for requested dates"
                  rows={3}
                  required
                  style={{
                    width: '100%',
                    padding: '0.5rem',
                    border: '1px solid var(--color-border)',
                    borderRadius: 4,
                  }}
                />
              </div>
              <div style={{ display: 'flex', gap: '0.5rem' }}>
                <button
                  onClick={handleDecline}
                  disabled={actionLoading || !declineReason.trim()}
                  style={{
                    padding: '0.5rem 1rem',
                    background: '#dc2626',
                    color: 'white',
                    border: 'none',
                    borderRadius: 4,
                    cursor: actionLoading ? 'not-allowed' : 'pointer',
                  }}
                >
                  {actionLoading ? 'Declining...' : 'Decline'}
                </button>
                <button
                  onClick={() => setShowDecline(false)}
                  style={{
                    padding: '0.5rem 1rem',
                    background: 'transparent',
                    border: '1px solid var(--color-border)',
                    borderRadius: 4,
                    cursor: 'pointer',
                  }}
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
