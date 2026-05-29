-- ============================================================
-- BCM Cronograma · Schema
-- Execute no Supabase: SQL Editor → New query → Cole → Run
-- ============================================================

-- 1. PROFILES (extensão de auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id        UUID    REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  name      TEXT,
  email     TEXT,
  role      TEXT    DEFAULT 'tecnico' CHECK (role IN ('admin','gestor','tecnico','cliente')),
  active    BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 2. PROJECTS
CREATE TABLE IF NOT EXISTS projects (
  id         BIGSERIAL PRIMARY KEY,
  name       TEXT NOT NULL,
  client     TEXT,
  location   TEXT,
  start_date DATE,
  end_date   DATE,
  status     TEXT DEFAULT 'active' CHECK (status IN ('active','paused','done')),
  created_by UUID REFERENCES auth.users,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- 3. PROJECT MEMBERS
CREATE TABLE IF NOT EXISTS project_members (
  project_id BIGINT REFERENCES projects ON DELETE CASCADE,
  user_id    UUID   REFERENCES auth.users ON DELETE CASCADE,
  role       TEXT   DEFAULT 'tecnico',
  PRIMARY KEY (project_id, user_id)
);
ALTER TABLE project_members ENABLE ROW LEVEL SECURITY;

-- 4. TASKS
CREATE TABLE IF NOT EXISTS tasks (
  id          BIGSERIAL PRIMARY KEY,
  project_id  BIGINT NOT NULL REFERENCES projects ON DELETE CASCADE,
  category    TEXT NOT NULL,
  name        TEXT NOT NULL,
  start_date  DATE NOT NULL,
  end_date    DATE NOT NULL,
  duration    INT,
  responsible TEXT,
  progress    INT  DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  order_idx   INT  DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- 5. PROGRESS LOG
CREATE TABLE IF NOT EXISTS progress_log (
  id         BIGSERIAL PRIMARY KEY,
  task_id    BIGINT NOT NULL REFERENCES tasks ON DELETE CASCADE,
  user_id    UUID   NOT NULL REFERENCES auth.users,
  progress   INT    NOT NULL,
  note       TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE progress_log ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Auto-cria perfil quando usuário se cadastra
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email,'@',1)),
    NEW.email,
    'tecnico'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Atualiza tasks.progress quando progress_log recebe entrada
CREATE OR REPLACE FUNCTION public.sync_task_progress()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE tasks SET progress = NEW.progress WHERE id = NEW.task_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_progress_inserted ON progress_log;
CREATE TRIGGER on_progress_inserted
  AFTER INSERT ON progress_log
  FOR EACH ROW EXECUTE FUNCTION public.sync_task_progress();

-- ============================================================
-- HELPER FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION public.my_role()
RETURNS TEXT LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$;

-- ============================================================
-- RLS POLICIES
-- ============================================================

-- PROFILES: todos autenticados podem ver, só admin altera qualquer um
CREATE POLICY "profiles_read"    ON profiles FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "profiles_insert"  ON profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_update"  ON profiles FOR UPDATE TO authenticated
  USING (my_role() = 'admin' OR id = auth.uid())
  WITH CHECK (
    my_role() = 'admin'
    OR (id = auth.uid() AND role = (SELECT role FROM profiles WHERE id = auth.uid()))
  );

-- PROJECTS
CREATE POLICY "projects_read"   ON projects FOR SELECT TO authenticated
  USING (
    my_role() = 'admin'
    OR EXISTS (SELECT 1 FROM project_members WHERE project_id = id AND user_id = auth.uid())
  );
CREATE POLICY "projects_insert" ON projects FOR INSERT TO authenticated
  WITH CHECK (my_role() IN ('admin','gestor'));
CREATE POLICY "projects_update" ON projects FOR UPDATE TO authenticated
  USING (my_role() IN ('admin','gestor'));
CREATE POLICY "projects_delete" ON projects FOR DELETE TO authenticated
  USING (my_role() = 'admin');

-- PROJECT MEMBERS
CREATE POLICY "members_read"   ON project_members FOR SELECT TO authenticated
  USING (
    my_role() = 'admin'
    OR user_id = auth.uid()
    OR (my_role() = 'gestor' AND
        EXISTS (SELECT 1 FROM project_members pm2 WHERE pm2.project_id = project_id AND pm2.user_id = auth.uid()))
  );
CREATE POLICY "members_insert" ON project_members FOR INSERT TO authenticated
  WITH CHECK (my_role() IN ('admin','gestor'));
CREATE POLICY "members_delete" ON project_members FOR DELETE TO authenticated
  USING (my_role() IN ('admin','gestor'));

-- TASKS: acesso via membership do projeto
CREATE POLICY "tasks_read"   ON tasks FOR SELECT TO authenticated
  USING (
    my_role() = 'admin'
    OR EXISTS (SELECT 1 FROM project_members WHERE project_id = tasks.project_id AND user_id = auth.uid())
  );
CREATE POLICY "tasks_insert" ON tasks FOR INSERT TO authenticated
  WITH CHECK (my_role() IN ('admin','gestor'));
CREATE POLICY "tasks_update" ON tasks FOR UPDATE TO authenticated
  USING (my_role() IN ('admin','gestor'));
CREATE POLICY "tasks_delete" ON tasks FOR DELETE TO authenticated
  USING (my_role() IN ('admin','gestor'));

-- PROGRESS LOG: técnico pode inserir, cliente só lê
CREATE POLICY "progress_read"   ON progress_log FOR SELECT TO authenticated
  USING (
    my_role() = 'admin'
    OR EXISTS (
      SELECT 1 FROM tasks t
      JOIN project_members pm ON pm.project_id = t.project_id
      WHERE t.id = task_id AND pm.user_id = auth.uid()
    )
  );
CREATE POLICY "progress_insert" ON progress_log FOR INSERT TO authenticated
  WITH CHECK (
    my_role() != 'cliente'
    AND user_id = auth.uid()
    AND (
      my_role() = 'admin'
      OR EXISTS (
        SELECT 1 FROM tasks t
        JOIN project_members pm ON pm.project_id = t.project_id
        WHERE t.id = task_id AND pm.user_id = auth.uid()
      )
    )
  );
