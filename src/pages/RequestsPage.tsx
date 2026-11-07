import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Table, Button, Tag, Typography, Modal, Form, Input, Select, message, Space } from 'antd';
import { useAuth } from '@/auth/useAuth';
import { fetchRequests, createRequest } from '@/api/requests';
import { fetchAllProfiles } from '@/api/profiles';
import type { Request, Profile, Urgency } from '@/api/types';
import { StatusTag } from '@/components/StatusTag';
import { URGENCY_LABEL } from '@/lib/statuses';

export function RequestsPage() {
  const { profile } = useAuth();
  const navigate = useNavigate();
  const isDispatcher = profile?.role === 'dispatcher';

  const [requests, setRequests] = useState<Request[]>([]);
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [form] = Form.useForm();

  const nameById = useMemo(() => new Map(profiles.map((p) => [p.id, p.full_name || p.email])), [profiles]);
  const masters = useMemo(() => profiles.filter((p) => p.role === 'master'), [profiles]);

  const load = async () => {
    setLoading(true);
    try {
      const [r, p] = await Promise.all([fetchRequests(), fetchAllProfiles()]);
      setRequests(r);
      setProfiles(p);
    } catch (e) {
      message.error(e instanceof Error ? e.message : 'Ошибка загрузки');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const onCreate = async (v: { address: string; description: string; urgency: Urgency; master_id: string }) => {
    try {
      await createRequest(v);
      message.success('Заявка создана');
      setModalOpen(false);
      form.resetFields();
      load();
    } catch (e) {
      message.error(e instanceof Error ? e.message : 'Не удалось создать');
    }
  };

  return (
    <>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }}>
        <Typography.Title level={3} style={{ margin: 0 }}>
          {isDispatcher ? 'Все заявки' : 'Мои заявки'}
        </Typography.Title>
        {isDispatcher && (
          <Button type="primary" onClick={() => setModalOpen(true)}>
            Новая заявка
          </Button>
        )}
      </Space>

      <Table<Request>
        rowKey="id"
        loading={loading}
        dataSource={requests}
        pagination={false}
        onRow={(r) => ({ onClick: () => navigate(`/requests/${r.id}`), style: { cursor: 'pointer' } })}
        columns={[
          { title: 'Адрес', dataIndex: 'address' },
          { title: 'Проблема', dataIndex: 'description', ellipsis: true },
          {
            title: 'Срочность',
            dataIndex: 'urgency',
            render: (u: Urgency) => (u === 'urgent' ? <Tag color="volcano">Срочная</Tag> : <Tag>Обычная</Tag>),
          },
          { title: 'Мастер', dataIndex: 'master_id', render: (id: string) => nameById.get(id) ?? '—' },
          { title: 'Статус', dataIndex: 'status', render: (s) => <StatusTag status={s} /> },
        ]}
      />

      <Modal
        title="Новая заявка"
        open={modalOpen}
        onCancel={() => setModalOpen(false)}
        onOk={() => form.submit()}
        okText="Создать"
        cancelText="Отмена"
      >
        <Form form={form} layout="vertical" onFinish={onCreate} initialValues={{ urgency: 'normal' }}>
          <Form.Item name="address" label="Адрес" rules={[{ required: true, message: 'Укажите адрес' }]}>
            <Input />
          </Form.Item>
          <Form.Item name="description" label="Описание проблемы" rules={[{ required: true, message: 'Опишите проблему' }]}>
            <Input.TextArea rows={3} />
          </Form.Item>
          <Form.Item name="urgency" label="Срочность">
            <Select
              options={(['normal', 'urgent'] as Urgency[]).map((u) => ({ value: u, label: URGENCY_LABEL[u] }))}
            />
          </Form.Item>
          <Form.Item name="master_id" label="Мастер" rules={[{ required: true, message: 'Назначьте мастера' }]}>
            <Select
              options={masters.map((m) => ({ value: m.id, label: m.full_name || m.email }))}
              placeholder="Выберите мастера"
            />
          </Form.Item>
        </Form>
      </Modal>
    </>
  );
}
