-- Adiciona coluna parent_task_id para hierarquia de tarefas (pai → filho → neto)
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS parent_task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL;

-- Índice para consultas de filhos por pai
CREATE INDEX IF NOT EXISTS idx_tasks_parent ON tasks(parent_task_id);
