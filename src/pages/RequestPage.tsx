import { useEffect, useMemo, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  Card, Descriptions, Button, Space, Timeline, Typography, Modal, Input, Select, message, Spin, Tag,
} from 'antd';
import dayjs from 'dayjs';
import { useAuth } from '@/auth/useAuth';
import { fetchRequest, fetchHistory, changeRequestStatus } from '@/api/requests';
import { fetchAllProfiles } from '@/api/profiles';
import type { Request, RequestHistory, Profile } from '@/api/types';
import { StatusTag } from '@/components/StatusTag';
import { STATUS_LABEL } from '@/lib/statuses';
import { getAvailableActions, type RequestAction } from '@/lib/requestActions';

export function RequestPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const { profile } = useAuth();

  const [request, setRequest] = useState<Request | null>(null);
  const [history, setHistory] = useState<RequestHistory[]>([]);
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);

  const [action, setAction] = useState<RequestAction | null>(null);
  const [comment, setComment] = useState('');
  const [newMaster, setNewMaster] = useState<string | undefined>();
  const [submitting, setSubmitting] = useState(false);

  const nameById = useMemo(() => new Map(profiles.map((p) => [p.id, p.full_name || p.email])), [profiles]);
  const otherMasters = useMemo(
    () => profiles.filter((p) => p.role === 'master' && p.id !== request?.master_id),
    [profiles, request],
  );

  const load = async () => {
    setLoading(true);
    try {
      const [r, h, p] = await Promise.all([fetchRequest(id), fetchHistory(id), fetchAllProfiles()]);
      setRequest(r);
      setHistory(h);
      setProfiles(p);
    } catch (e) {
      message.error(e instanceof Error ? e.message : 'Заявка не найдена');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const actions = request && profile ? getAvailableActions(request, profile) : [];

  const startAction = (a: RequestAction) => {
    if (a.needsComment || a.needsNewMaster) {
      setComment('');
      setNewMaster(undefined);
      setAction(a);
    } else {
      Modal.confirm({
        title: `Подтвердите: ${a.label}`,
        okText: 'Да',
        cancelText: 'Отмена',
        onOk: () => runAction(a),
      });
    }
  };

  const runAction = async (a: RequestAction, c?: string, nm?: string) => {
    setSubmitting(true);
    try {
      await changeRequestStatus({ requestId: id, to: a.to, comment: c ?? null, newMaster: nm ?? null });
      message.success('Готово');
      setAction(null);
      await load();
    } catch (e) {
      message.error(e instanceof Error ? e.message : 'Не удалось');
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) return <Spin size="large" style={{ display: 'block', margin: '80px auto' }} />;
  if (!request) return <Typography.Text>Заявка не найдена.</Typography.Text>;

  return (
    <>
      <Button onClick={() => navigate('/')} style={{ marginBottom: 16 }}>
        ← К списку
      </Button>

      <Card
        title={request.address}
        extra={<StatusTag status={request.status} />}
        style={{ marginBottom: 16 }}
      >
        <Descriptions column={1} size="small">
          <Descriptions.Item label="Проблема">{request.description}</Descriptions.Item>
          <Descriptions.Item label="Срочность">
            {request.urgency === 'urgent' ? <Tag color="volcano">Срочная</Tag> : <Tag>Обычная</Tag>}
          </Descriptions.Item>
          <Descriptions.Item label="Мастер">{nameById.get(request.master_id) ?? '—'}</Descriptions.Item>
          <Descriptions.Item label="Создал">{nameById.get(request.author_id) ?? '—'}</Descriptions.Item>
          <Descriptions.Item label="Создана">{dayjs(request.created_at).format('DD.MM.YYYY HH:mm')}</Descriptions.Item>
        </Descriptions>

        {actions.length > 0 && (
          <Space style={{ marginTop: 16 }} wrap>
            {actions.map((a) => (
              <Button key={a.to} type="primary" danger={a.danger} onClick={() => startAction(a)}>
                {a.label}
              </Button>
            ))}
          </Space>
        )}
      </Card>

      <Card title="История">
        <Timeline
          items={history.map((h) => ({
            color: h.to_status === 'rejected' ? 'red' : h.to_status === 'done' ? 'green' : 'blue',
            children: (
              <div>
                <Typography.Text strong>
                  {h.from_status ? `${STATUS_LABEL[h.from_status]} → ` : 'Создана → '}
                  {STATUS_LABEL[h.to_status]}
                </Typography.Text>
                <div style={{ fontSize: 12, color: '#888' }}>
                  {nameById.get(h.changed_by) ?? '—'} · {dayjs(h.created_at).format('DD.MM.YYYY HH:mm')}
                </div>
                {h.comment && <div style={{ marginTop: 4 }}>{h.comment}</div>}
              </div>
            ),
          }))}
        />
      </Card>

      <Modal
        title={action?.label}
        open={!!action}
        onCancel={() => setAction(null)}
        confirmLoading={submitting}
        okText="Подтвердить"
        cancelText="Отмена"
        onOk={() => {
          if (action?.needsComment && !comment.trim()) {
            message.warning('Нужен комментарий');
            return;
          }
          if (action?.needsNewMaster && !newMaster) {
            message.warning('Выберите другого мастера');
            return;
          }
          if (action) runAction(action, comment, newMaster);
        }}
      >
        {action?.needsNewMaster && (
          <div style={{ marginBottom: 12 }}>
            <Typography.Text>Новый мастер:</Typography.Text>
            <Select
              style={{ width: '100%', marginTop: 4 }}
              value={newMaster}
              onChange={setNewMaster}
              placeholder="Выберите другого мастера"
              options={otherMasters.map((m) => ({ value: m.id, label: m.full_name || m.email }))}
            />
          </div>
        )}
        {action?.needsComment && (
          <div>
            <Typography.Text>Комментарий{action.to === 'rejected' ? ' (причина отказа)' : ''}:</Typography.Text>
            <Input.TextArea rows={3} value={comment} onChange={(e) => setComment(e.target.value)} style={{ marginTop: 4 }} />
          </div>
        )}
      </Modal>
    </>
  );
}
