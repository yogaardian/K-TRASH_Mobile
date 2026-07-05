/**
 * INTEGRATION GUIDE FOR APP.JS
 * 
 * This file shows how to integrate the new Context providers into your main App.js
 */

// ============================================
// BEFORE (Current structure)
// ============================================
/*
import React from 'react';
import routes from './routes';

function App() {
  return (
    <div className="wrapper">
      {routes}
    </div>
  );
}

export default App;
*/

// ============================================
// AFTER (With Context Providers)
// ============================================
/*
import React from 'react';
import routes from './routes';
import { AuthProvider, DashboardProvider } from './context/AppContext';

function App() {
  return (
    <AuthProvider>
      <DashboardProvider>
        <div className="wrapper">
          {routes}
        </div>
      </DashboardProvider>
    </AuthProvider>
  );
}

export default App;
*/

// ============================================
// HOW TO USE IN COMPONENTS
// ============================================

// 1. Using Auth Context
/*
import { useAuth } from '../context/AppContext';

function MyComponent() {
  const { user, isLoading, logout } = useAuth();
  
  if (isLoading) return <div>Loading user...</div>;
  
  return (
    <div>
      <p>Welcome {user?.nama}!</p>
      <p>Role: {user?.role}</p>
      <button onClick={logout}>Logout</button>
    </div>
  );
}
*/

// 2. Using Dashboard Context
/*
import { useDashboard } from '../context/AppContext';

function Dashboard() {
  const { dashboardData, isLoading, error, refresh } = useDashboard();
  
  if (isLoading) return <Spinner />;
  if (error) return <Alert variant="danger">{error}</Alert>;
  
  return (
    <div>
      <button onClick={refresh}>Refresh</button>
      <pre>{JSON.stringify(dashboardData, null, 2)}</pre>
    </div>
  );
}
*/

// 3. Combined Usage
/*
import { useAuth } from '../context/AppContext';
import { useDashboard } from '../context/AppContext';

function FullDashboard() {
  const { user } = useAuth();
  const { dashboardData, isLoading } = useDashboard();
  
  return (
    <div>
      <h1>Welcome {user?.nama}</h1>
      {isLoading && <Spinner />}
      {!isLoading && <Stats data={dashboardData} />}
    </div>
  );
}
*/

// ============================================
// PROTECTED ROUTE EXAMPLE
// ============================================
/*
import { useAuth } from '../context/AppContext';
import { Route, Redirect } from 'react-router-dom';

function ProtectedRoute({ component: Component, requiredRole, ...rest }) {
  const { user, isLoading } = useAuth();
  
  if (isLoading) return <div>Loading...</div>;
  
  return (
    <Route
      {...rest}
      render={(props) =>
        user && (requiredRole ? user.role === requiredRole : true) ? (
          <Component {...props} />
        ) : (
          <Redirect to="/login" />
        )
      }
    />
  );
}

// Usage in routes
<ProtectedRoute
  exact
  path="/admin"
  component={Dashboard}
  requiredRole="admin"
/>
*/

export default {};
