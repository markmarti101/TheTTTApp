import { Outlet, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export function Layout() {
  const { profile, signOut } = useAuth();

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <header
        style={{
          padding: '1rem 2rem',
          borderBottom: '1px solid var(--color-border)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <h1 style={{ margin: 0, fontSize: '1.25rem' }}>The Training Triangle</h1>
        <nav style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
          <Link to="/">Dashboard</Link>
          {profile?.role === 'training_company' && (
            <Link to="/requests">Requests</Link>
          )}
          <button
            onClick={() => signOut()}
            style={{
              padding: '0.25rem 0.5rem',
              background: 'transparent',
              border: '1px solid var(--color-border)',
              borderRadius: 4,
              cursor: 'pointer',
              fontSize: 14,
            }}
          >
            Sign out
          </button>
        </nav>
      </header>
      <main style={{ flex: 1, padding: '2rem' }}>
        <Outlet />
      </main>
    </div>
  );
}
