import { Layout, Typography, Space, Button, Tag } from 'antd';
import { Outlet, Link } from 'react-router-dom';
import { useAuth } from '@/auth/useAuth';

const { Header, Content } = Layout;

export function AppLayout() {
  const { profile, signOut } = useAuth();
  const isDispatcher = profile?.role === 'dispatcher';

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
        <Link to="/" style={{ color: '#fff', fontWeight: 600, fontSize: 16 }}>
          Заявки на ремонт
        </Link>
        <div style={{ flex: 1 }} />
        <Space>
          <Tag color={isDispatcher ? 'gold' : 'blue'}>{isDispatcher ? 'Диспетчер' : 'Мастер'}</Tag>
          <Typography.Text style={{ color: '#fff' }}>{profile?.full_name || profile?.email}</Typography.Text>
          <Button size="small" onClick={() => signOut()}>
            Выйти
          </Button>
        </Space>
      </Header>
      <Content style={{ padding: 24, maxWidth: 1000, margin: '0 auto', width: '100%' }}>
        <Outlet />
      </Content>
    </Layout>
  );
}
