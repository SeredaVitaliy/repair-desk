import { Routes, Route } from 'react-router-dom';
import { PrivateRoute } from '@/components/PrivateRoute';
import { AppLayout } from '@/components/AppLayout';
import { LoginPage } from '@/pages/LoginPage';
import { RequestsPage } from '@/pages/RequestsPage';
import { RequestPage } from '@/pages/RequestPage';

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<PrivateRoute />}>
        <Route element={<AppLayout />}>
          <Route index element={<RequestsPage />} />
          <Route path="requests/:id" element={<RequestPage />} />
        </Route>
      </Route>
    </Routes>
  );
}
