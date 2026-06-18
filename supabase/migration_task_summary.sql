-- Permite marcar uma tarefa como "resumo/pai" mesmo sem filhos ainda.
-- Usado pelo botão Recuar (◀) no cronograma: ao recuar uma tarefa no nível
-- principal, ela vira um pai (negrito + barra resumo) e adota a próxima abaixo.
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS is_summary BOOLEAN DEFAULT false;
