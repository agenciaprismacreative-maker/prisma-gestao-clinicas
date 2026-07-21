# Adendo à Especificação: Novas Oportunidades Identificadas

Projeto: Prisma Creative · Sistema de Gestão para Clínicas de Estética
Referência: complementa o documento original de julho de 2026
Origem: anotações manuscritas revisadas em reunião de análise, 21 de julho de 2026

Este adendo não substitui a especificação original. Registra pontos novos, identificados depois da primeira versão do documento, e indica em que fase da ordem de construção cada um se encaixa.

## 1. Recomendação de próximo procedimento via IA

Camada de inteligência que analisa o histórico clínico e as fotos de evolução do paciente e sugere o próximo procedimento indicado, com base no resultado observado, não apenas no tempo decorrido desde a última sessão. É um avanço em relação à régua de reativação (que dispara por prazo) e ao apoio de IA no prontuário já previstos: aqui a sugestão nasce da evolução real registrada, o que transforma o sistema em ferramenta de venda consultiva, não só de lembrete.

Depende de prontuário e fotos de evolução já maduros para gerar sugestões confiáveis. Encaixa na fase 6 da ordem de construção (assistente de gestão e apoio de IA), junto com o restante da camada de inteligência artificial.

## 2. Oportunidade de receita visível no painel

Indicador de dashboard que converte dados operacionais em receita projetada: soma pacientes inativos elegíveis à reativação, pacotes perto de vencer sem renovação e as sugestões de novo procedimento do item 1. Desdobramento direto do painel cruzado entre marketing e atendimento, já descrito como diferencial na especificação original. É um dos pontos de maior apelo comercial para demonstrar valor ao dono da clínica.

Depende dos dados de pós-venda e da camada de IA já estarem implementados. Encaixa junto com as fases 5 e 6.

## 3. Calculadora de custo de insumos

Ponto novo em relação ao modelo de dados original. Requer duas adições ao schema: uma tabela de produtos ou insumos com custo unitário, e uma tabela de vínculo entre serviço e os insumos consumidos por sessão. Com isso, o sistema calcula a margem líquida real por procedimento, não apenas o preço cobrado ao paciente. Encaixa na fase 3 (equipe, tarefas, financeiro e estoque), junto com o restante do módulo financeiro.

## 4. Assistente com conhecimento aprofundado do negócio

Extensão do assistente de gestão já previsto (que a especificação original desenha sobre a API da Claude): um assistente que constrói uma base de conhecimento específica de cada clínica, cobrindo perfil de público, catálogo de procedimentos e histórico de vendas, para gerar relatórios de venda e suporte mais personalizados do que uma pergunta pontual em linguagem natural. A avaliação de qual provedor de IA usar para essa camada (Claude, OpenAI, ou combinação dos dois) fica em aberto e será decidida quando o projeto chegar nessa fase, com base no que estiver disponível e no custo em vigor no momento. Encaixa na fase 6.

## 5. Confirmação de agendamento por link

Complemento ao fluxo de confirmação via WhatsApp já especificado. Em vez de apenas responder sim ou não por texto, o paciente recebe um link que abre uma página curta com os detalhes do agendamento. Funciona como uma antecipação parcial da experiência do futuro aplicativo do paciente (fase 8), sem depender dele estar pronto. Encaixa como incremento da fase 1 (agenda e confirmação automática) ou da fase 5 (pós-venda), a depender do ritmo do projeto.

## 6. Usabilidade no registro de evolução

Requisito de usabilidade para a tela de atendimento e prontuário, ainda não construída: etapas de evolução apresentadas de forma clara e fluxo rápido para adicionar fotos durante o atendimento, sem etapas desnecessárias. Será aplicado como critério de design quando essa tela for desenvolvida, na fase 2.

## 7. Ponto de extensão para integração com CRM externo

Registrado como decisão em aberto: o sistema deve manter a possibilidade de, no futuro, sincronizar leads e pacientes com um CRM externo ainda não escolhido. Não é uma integração a construir agora, é uma diretriz de arquitetura: ao desenhar a camada comercial (fase 4), evitar decisões que dificultem uma integração externa futura, sem comprometer com uma ferramenta específica antes de ela ser definida.

## 8. Nota estratégica: outros nichos

Observação registrada para referência futura, sem efeito sobre a arquitetura atual: o modelo de agendamento, acompanhamento automático e comunicação via WhatsApp construído para clínicas de estética tem apelo semelhante em outros nichos de serviço, como agências de turismo, cujos clientes enfrentam dores parecidas de organização de agendamentos e acompanhamento. Fica como possível direção de produto a explorar depois que o sistema estiver validado no nicho original, sem mudar nomenclatura ou estrutura de dados agora.
