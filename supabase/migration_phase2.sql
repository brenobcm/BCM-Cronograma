-- ============================================================
-- BCM Cronograma · Fase 2 — Schema Completo
-- Execute no Supabase: SQL Editor → New query → Run
-- ============================================================

-- ── 1. CATEGORIAS DE CUSTO ────────────────────────────────────
CREATE TABLE IF NOT EXISTS cost_categories (
  id   BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT DEFAULT 'labor' CHECK (type IN ('labor','material','equipment','subcontractor','other'))
);
INSERT INTO cost_categories (name,type) VALUES
  ('Mão de Obra Direta','labor'),
  ('Mão de Obra Indireta','labor'),
  ('Material Elétrico','material'),
  ('Material Civil','material'),
  ('Equipamento','equipment'),
  ('Subcontratado','subcontractor'),
  ('Despesas Gerais','other')
ON CONFLICT DO NOTHING;

-- ── 2. FUNCIONÁRIOS ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employees (
  id            BIGSERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  email         TEXT,
  phone         TEXT,
  role          TEXT,                        -- Eletricista, Técnico, Engenheiro...
  hourly_rate   DECIMAL(10,2) DEFAULT 0,     -- R$/hora
  daily_hours   DECIMAL(4,2)  DEFAULT 9,     -- horas por dia útil
  active        BOOLEAN DEFAULT TRUE,
  user_id       UUID REFERENCES auth.users,  -- conta no sistema (opcional)
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- ── 3. TIPOS DE PAINEL ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS panel_types (
  id          BIGSERIAL PRIMARY KEY,
  code        TEXT NOT NULL,
  name        TEXT NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE panel_types ENABLE ROW LEVEL SECURITY;

-- ── 4. ATIVIDADES PADRÃO POR TIPO DE PAINEL ───────────────────
CREATE TABLE IF NOT EXISTS panel_activities (
  id             BIGSERIAL PRIMARY KEY,
  panel_type_id  BIGINT NOT NULL REFERENCES panel_types ON DELETE CASCADE,
  name           TEXT NOT NULL,
  std_hours      DECIMAL(8,2) DEFAULT 0,   -- horas padrão
  unit_cost      DECIMAL(10,2) DEFAULT 0,  -- custo unitário padrão
  description    TEXT,
  order_idx      INT DEFAULT 0
);
ALTER TABLE panel_activities ENABLE ROW LEVEL SECURITY;

-- ── 5. DEPENDÊNCIAS ENTRE TAREFAS ─────────────────────────────
CREATE TABLE IF NOT EXISTS task_dependencies (
  task_id        BIGINT NOT NULL REFERENCES tasks ON DELETE CASCADE,
  predecessor_id BIGINT NOT NULL REFERENCES tasks ON DELETE CASCADE,
  type           TEXT DEFAULT 'FS' CHECK (type IN ('FS','SS','FF','SF')),
  lag_days       INT DEFAULT 0,
  PRIMARY KEY (task_id, predecessor_id)
);
ALTER TABLE task_dependencies ENABLE ROW LEVEL SECURITY;

-- ── 6. ALOCAÇÃO FUNCIONÁRIO × TAREFA ─────────────────────────
CREATE TABLE IF NOT EXISTS task_employees (
  id              BIGSERIAL PRIMARY KEY,
  task_id         BIGINT NOT NULL REFERENCES tasks ON DELETE CASCADE,
  employee_id     BIGINT NOT NULL REFERENCES employees ON DELETE CASCADE,
  allocation_pct  DECIMAL(5,2) DEFAULT 100,   -- % alocação (100 = integral)
  planned_hours   DECIMAL(8,2),               -- preenchido auto ou manual
  actual_hours    DECIMAL(8,2) DEFAULT 0,
  UNIQUE(task_id, employee_id)
);
ALTER TABLE task_employees ENABLE ROW LEVEL SECURITY;

-- ── 7. REGISTRO DE HORAS REAIS ────────────────────────────────
CREATE TABLE IF NOT EXISTS time_entries (
  id          BIGSERIAL PRIMARY KEY,
  task_id     BIGINT NOT NULL REFERENCES tasks ON DELETE CASCADE,
  employee_id BIGINT NOT NULL REFERENCES employees,
  work_date   DATE NOT NULL,
  hours       DECIMAL(5,2) NOT NULL CHECK (hours > 0 AND hours <= 24),
  description TEXT,
  approved    BOOLEAN DEFAULT FALSE,
  created_by  UUID REFERENCES auth.users,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE time_entries ENABLE ROW LEVEL SECURITY;

-- ── 8. CALENDÁRIO DE TRABALHO (FERIADOS) ─────────────────────
CREATE TABLE IF NOT EXISTS work_calendar (
  id          BIGSERIAL PRIMARY KEY,
  cal_date    DATE NOT NULL UNIQUE,
  type        TEXT DEFAULT 'holiday',
  description TEXT
);
ALTER TABLE work_calendar ENABLE ROW LEVEL SECURITY;

-- Feriados nacionais 2026
INSERT INTO work_calendar (cal_date, type, description) VALUES
  ('2026-01-01','holiday','Confraternização Universal'),
  ('2026-04-03','holiday','Paixão de Cristo'),
  ('2026-04-05','holiday','Páscoa'),
  ('2026-04-21','holiday','Tiradentes'),
  ('2026-05-01','holiday','Dia do Trabalho'),
  ('2026-06-04','holiday','Corpus Christi'),
  ('2026-09-07','holiday','Independência do Brasil'),
  ('2026-10-12','holiday','Nossa Senhora Aparecida'),
  ('2026-11-02','holiday','Finados'),
  ('2026-11-15','holiday','Proclamação da República'),
  ('2026-12-25','holiday','Natal')
ON CONFLICT (cal_date) DO NOTHING;

-- ── 9. ITENS DE ORÇAMENTO ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS budget_items (
  id                BIGSERIAL PRIMARY KEY,
  task_id           BIGINT REFERENCES tasks ON DELETE CASCADE,
  project_id        BIGINT NOT NULL REFERENCES projects ON DELETE CASCADE,
  category_id       BIGINT REFERENCES cost_categories,
  description       TEXT NOT NULL,
  unit              TEXT DEFAULT 'un',
  planned_qty       DECIMAL(12,3) DEFAULT 1,
  planned_unit_cost DECIMAL(12,2) DEFAULT 0,
  planned_total     DECIMAL(12,2) DEFAULT 0,
  actual_total      DECIMAL(12,2) DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE budget_items ENABLE ROW LEVEL SECURITY;

-- ── 10. MARCOS DE FATURAMENTO ────────────────────────────────
CREATE TABLE IF NOT EXISTS billing_milestones (
  id          BIGSERIAL PRIMARY KEY,
  project_id  BIGINT NOT NULL REFERENCES projects ON DELETE CASCADE,
  name        TEXT NOT NULL,
  due_date    DATE,
  amount      DECIMAL(12,2) DEFAULT 0,
  paid        BOOLEAN DEFAULT FALSE,
  paid_date   DATE,
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE billing_milestones ENABLE ROW LEVEL SECURITY;

-- ── 11. LINHA DE BASE ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS baselines (
  id         BIGSERIAL PRIMARY KEY,
  project_id BIGINT NOT NULL REFERENCES projects ON DELETE CASCADE,
  name       TEXT NOT NULL DEFAULT 'Baseline 1',
  created_by UUID REFERENCES auth.users,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE baselines ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS baseline_tasks (
  id          BIGSERIAL PRIMARY KEY,
  baseline_id BIGINT NOT NULL REFERENCES baselines ON DELETE CASCADE,
  task_id     BIGINT NOT NULL REFERENCES tasks,
  start_date  DATE,
  end_date    DATE,
  progress    INT DEFAULT 0
);
ALTER TABLE baseline_tasks ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- FUNÇÕES UTILITÁRIAS
-- ============================================================

-- Calcula dias úteis entre duas datas (excluindo fins de semana e feriados)
CREATE OR REPLACE FUNCTION public.working_days(start_date DATE, end_date DATE)
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  days INT := 0;
  cur  DATE := start_date;
BEGIN
  WHILE cur <= end_date LOOP
    IF EXTRACT(DOW FROM cur) NOT IN (0,6)
       AND NOT EXISTS (SELECT 1 FROM work_calendar WHERE cal_date = cur) THEN
      days := days + 1;
    END IF;
    cur := cur + 1;
  END LOOP;
  RETURN days;
END;
$$;

-- Calcula horas planejadas de uma tarefa (dias úteis × 9h × alocação%)
CREATE OR REPLACE FUNCTION public.calc_planned_hours(
  p_start DATE, p_end DATE, p_alloc DECIMAL DEFAULT 100
) RETURNS DECIMAL LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT ROUND(public.working_days(p_start, p_end) * 9 * (p_alloc/100.0), 2);
$$;

-- ============================================================
-- RLS POLICIES — novas tabelas
-- ============================================================

-- EMPLOYEES: admin/gestor gerenciam, técnico/cliente leem
CREATE POLICY "emp_read"   ON employees FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "emp_insert" ON employees FOR INSERT TO authenticated
  WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));
CREATE POLICY "emp_update" ON employees FOR UPDATE TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));
CREATE POLICY "emp_delete" ON employees FOR DELETE TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- PANEL TYPES
CREATE POLICY "pt_read"   ON panel_types FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "pt_insert" ON panel_types FOR INSERT TO authenticated
  WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));
CREATE POLICY "pt_update" ON panel_types FOR UPDATE TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));
CREATE POLICY "pt_delete" ON panel_types FOR DELETE TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- PANEL ACTIVITIES
CREATE POLICY "pa_read"   ON panel_activities FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "pa_write"  ON panel_activities FOR ALL TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));

-- TASK DEPENDENCIES
CREATE POLICY "dep_read"  ON task_dependencies FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "dep_write" ON task_dependencies FOR ALL TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));

-- TASK EMPLOYEES
CREATE POLICY "te_read"   ON task_employees FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "te_write"  ON task_employees FOR ALL TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));

-- TIME ENTRIES
CREATE POLICY "time_read" ON time_entries FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "time_insert" ON time_entries FOR INSERT TO authenticated
  WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) != 'cliente');
CREATE POLICY "time_update" ON time_entries FOR UPDATE TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));

-- WORK CALENDAR
CREATE POLICY "cal_read"  ON work_calendar FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "cal_write" ON work_calendar FOR ALL TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- BUDGET ITEMS
CREATE POLICY "bud_read"  ON budget_items FOR SELECT TO authenticated
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    OR EXISTS (SELECT 1 FROM project_members WHERE project_id = budget_items.project_id AND user_id = auth.uid())
  );
CREATE POLICY "bud_write" ON budget_items FOR ALL TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));

-- BILLING MILESTONES
CREATE POLICY "bill_read"  ON billing_milestones FOR SELECT TO authenticated
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    OR EXISTS (SELECT 1 FROM project_members WHERE project_id = billing_milestones.project_id AND user_id = auth.uid())
  );
CREATE POLICY "bill_write" ON billing_milestones FOR ALL TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));

-- BASELINES
CREATE POLICY "base_read"  ON baselines FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "base_write" ON baselines FOR ALL TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));
CREATE POLICY "baset_read"  ON baseline_tasks FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "baset_write" ON baseline_tasks FOR ALL TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));
