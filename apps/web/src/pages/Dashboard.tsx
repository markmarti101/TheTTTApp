import { Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export function Dashboard() {
  const { profile } = useAuth();

  return (
    <div>
      <h2>Dashboard</h2>
      <p>
        Welcome{profile?.displayName ? `, ${profile.displayName}` : ''} (
        {profile?.role ?? '—'})
      </p>
      {profile?.role === 'training_company' && (
        <p>
          <Link to="/requests" style={{ color: 'var(--color-primary)' }}>
            View course requests →
          </Link>
        </p>
      )}
    </div>
  );
}
