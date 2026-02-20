import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { getRequestsByCompany } from '../services/requests';
import type { CourseRequest } from '@training-triangle/shared';

export function RequestsList() {
  const { profile } = useAuth();
  const [requests, setRequests] = useState<(CourseRequest & { id: string })[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!profile?.trainingCompanyId) {
      setLoading(false);
      return;
    }
    getRequestsByCompany(profile.trainingCompanyId)
      .then(setRequests)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [profile?.trainingCompanyId]);

  if (!profile?.trainingCompanyId) {
    return (
      <div>
        <h2>Course Requests</h2>
        <p>No training company linked to your account.</p>
      </div>
    );
  }

  if (loading) return <div>Loading requests...</div>;

  return (
    <div>
      <h2>Course Requests</h2>
      {requests.length === 0 ? (
        <p>No requests yet.</p>
      ) : (
        <ul style={{ listStyle: 'none', padding: 0 }}>
          {requests.map((r) => (
            <li
              key={r.id}
              style={{
                padding: '1rem',
                marginBottom: '0.5rem',
                border: '1px solid var(--color-border)',
                borderRadius: 8,
              }}
            >
              <Link
                to={`/requests/${r.id}`}
                style={{ textDecoration: 'none', color: 'inherit' }}
              >
                <strong>{r.title}</strong>
                {r.topic && ` — ${r.topic}`}
                <span
                  style={{
                    marginLeft: 8,
                    padding: '2px 8px',
                    borderRadius: 4,
                    fontSize: 12,
                    background:
                      r.status === 'approved'
                        ? '#dcfce7'
                        : r.status === 'declined'
                          ? '#fee2e2'
                          : '#fef3c7',
                  }}
                >
                  {r.status}
                </span>
                <div style={{ fontSize: 14, color: '#64748b', marginTop: 4 }}>
                  {new Date(r.createdAt).toLocaleDateString()}
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
