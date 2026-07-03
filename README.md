# LOST MEMORIES  
**Memórias Perdidas**

**Game Design Document (GDD)**  
**Versão 2.0.1 — 2026**

**Equipe de Desenvolvimento**  
Tadeu • Mariane • Pedro C • Pedro G • Luiz A

**Motor:** Godot 3.6.2 | **Plataforma:** PC (Windows)

## 1. Visão Geral do Projeto

| Campo              | Descrição                          |
|--------------------|------------------------------------|
| Título             | Lost Memories (Memórias Perdidas) |
| Gênero             | Horror Psicológico / Exploração Narrativa |
| Motor              | Godot 3.6.2 stable                |
| Plataforma         | PC (Windows)                      |
| Perspectiva        | Primeira Pessoa                   |
| Estética Visual    | Low-poly estilo PS1               |
| Duração estimada   | 30 a 60 minutos por partida       |
| Número de endings  | 2 (bom e ruim)                    |
| Classificação indicativa | 16+ (temas de morte, drogas, saúde mental) |

## 2. Sinopse
**A fazer**

## 3. História Detalhada

### 3.1 Protagonista

| Atributo       | Descrição |
|----------------|---------|
| Nome           | Laura |
| Condição       | Morta — presa no limbo na forma de sua casa de infância |
| Memória        | Completamente apagada no início do jogo |
| Personalidade (revelada via coletáveis) | Sensível, culpada, isolada, mas com momentos de leveza na infância |
| Dublagem       | Mariane |

### 3.2 Linha do Tempo da História
- Infância de Laura na casa — memórias felizes (reveladas via cartas antigas)
- Pai de Laura adoece gravemente
- Aniversário de 18 anos de Laura: o pai morre nesse dia
- A mãe culpa Laura por não ter usado o dinheiro da festa nos medicamentos do pai
- Laura sai de casa e corta contato com a mãe
- Laura começa a usar drogas como escapismo
- Num surto depressivo intenso, Laura induz uma overdose propositalmente
- Laura morre e acorda no limbo — a casa de infância — sem memória alguma

### 3.3 Estrutura Narrativa
A história é contada de forma não-linear, reconstruída pelo jogador através dos coletáveis. As fitas cassete revelam momentos emocionais e íntimos (a voz do pai, mensagens deixadas por Laura para si mesma). As cartas revelam os eventos objetivos da história.

O jogador monta o quebra-cabeça da vida de Laura progressivamente, chegando ao final com a imagem completa de quem ela foi.

## 4. Personagens

| Nome              | Papel                  | Dublagem                  | Observações |
|-------------------|------------------------|---------------------------|-----------|
| Laura             | Protagonista           | Emilly - Mariane                   | Narradora interna; reage aos ambientes |
| Pai de Laura      | Personagem ausente     | Tadeu                     | Presente apenas nas fitas cassete |
| A Sombra          | Ameaça / Antagonista   | Sem fala                  | Manifestação da culpa de Laura |
| Mãe de Laura      | Personagem ausente     | Bruna (especial)          | Mencionada nas cartas; voz nas fitas |
| Hannah            | Amiga da protagonista  | Eduarda Ayumi (especial)  | Protetora e maternal |
| Ryan              | Amigo da protagonista  | Luiz A                    | Descontraído, sensato |
| Ethan             | Amigo da protagonista  | Gabrel                    | Descontraído e brincalhão |

## 5. Core Loop

**EXPLORAR → ENCONTRAR COLETÁVEL → RECEBER MEMÓRIA → PROCESSAR NARRATIVA → EXPLORAR NOVAMENTE**

O jogador:
- Explora os cômodos da casa em primeira pessoa
- Encontra fitas cassete escondidas em locais difíceis
- Encontra cartas e bilhetes espalhados
- Ao coletar, recebe um fragmento da memória de Laura (áudio ou texto)
- A sombra aparece ocasionalmente, criando tensão
- O jogo salva automaticamente a cada 1 minuto
- Com memórias suficientes, desbloqueia o ending correspondente

## 6. Mecânicas de Jogo

### 6.1 Movimentação
- **Andar:** WASD
- **Correr:** Shift (consome stamina)
- **Câmera:** Mouse (FPS com head bob, tilt e sway)

### 6.2 Interação
- Raycast em primeira pessoa
- Crosshair muda ao mirar em objeto interagível
- Tecla **E** (ou clique) para interagir
- Objetos coletados desaparecem imediatamente

### 6.3 Coletáveis

| Tipo            | Quantidade prevista | Função |
|-----------------|---------------------|--------|
| Fitas Cassete   | ~8 a 12             | Fragmento de memória em áudio |
| Cartas / Bilhetes | ~10 a 15          | Fragmentos de memória em texto |
| Fotos           | ~5                  | Memórias visuais |

### 6.4 Sistema de Save — Slots e Autosave
Ao clicar em "Novo Jogo", o jogador escolhe um slot. O progresso é salvo automaticamente a cada 1 minuto nesse slot.  
As fitas cassete **não salvam** mais — são puramente narrativas.

### 6.5 Lanterna
Encontrada no início do jogo. Essencial para ambientes escuros.

### 6.6 A Sombra
- Surge aleatoriamente observando
- Ao detectar o jogador: apaga todas as luzes
- Efeito sonoro: passos e respiração pesada
- Representa a culpa de Laura

### 6.7 Ending

| Ending              | Condição                          | Descrição |
|---------------------|-----------------------------------|---------|
| **Bom — Paz**       | Coletar todos os coletáveis       | Laura aceita sua história e parte em paz |

## 7. Interface (HUD)
- Barra de stamina
- Crosshair dinâmico
- Inventário (tecla Tab) — apenas visual
- Notificação discreta de autosave

### 7.1 Gravador
Objeto fixo na casa. O jogador deve levar as fitas até ele para ouvir (cria ritual e exploração).

## 8. Ambientes

| Cômodo           | Descrição                              | Coletáveis esperados |
|------------------|----------------------------------------|----------------------|
| Quarto da Laura  | Primeiro ambiente, escuro e vazio     | 1 carta |
| Sala de estar    | Sala grande, estática                 | 1 fita, 1 carta |
| Cozinha          | Muito mal iluminada                   | 1 carta, 1 foto |
| Quarto do pai    | Cama, computador, violão, remédios    | 2 fitas, 3 cartas |
| Lavanderia       | Pequena, mal iluminada                | 1 carta |
| Banheiro         | Pequeno, apertado, mal iluminado      | 1 fita, 1 carta |

## 9. Identidade Visual e Sonora

### 9.1 Visual
- Low-poly com paleta dessaturada
- Texturas Nearest (estilo PS1)
- Shader VHS + filtro de câmera antiga
- Iluminação ambiente fraca

### 9.2 Sonoro
- Áudio das fitas com efeito de degradação
- Tema da Sombra: graves e respiração
- Dublagem completa (Laura, Pai, Mãe, Hannah, Ryan)

## 10. Backend e Sistema Online

### 10.1 Arquitetura
- **Client:** Godot 3.6.2
- **Backend:** Node.js + Express
- **Banco:** A definir (PostgreSQL ou MongoDB)

### 10.2 Funcionalidades
- Login/Cadastro
- Perfil do jogador
- Ranking Global
- Envio de dados ao finalizar a partida (tempo, coletáveis, ending)

## 11. Divisão de Tarefas da Equipe

| Membro    | Função Principal               | Tarefas principais |
|-----------|--------------------------------|--------------------|
| Tadeu     | Programação + Direção + Modelagem 3D | Todo código Godot, modelos, dublagem do pai |
| Mariane   | Dublagem + Game Design         | Voz de Laura, ideias de narrativa |
| Pedro C   | Documentação                   | Manter GDD e documentação do TCC |
| Pedro G   | Game Design / Ideias           | Puzzles e narrativa |
| Luiz A    | Game Design / Ideias           | Puzzles, narrativa e dublagem de Ryan |

## 12. Cronograma Macro

| Fase                  | Atividades                              | Status         |
|-----------------------|-----------------------------------------|----------------|
| Fase 1 — Pré-produção | GDD, tarefas, backend                   | Pronto         |
| Fase 2 — Prototipagem | Level layout, mecânicas básicas         | Pronto         |
| Fase 3 — Produção     | Ambientes, coletáveis, sombra, backend  | Em andamento   |
| Fase 4 — Polimento    | Shaders, sons, dificuldade              | Em andamento   |
| Fase 5 — Entrega      | Build final, documentação TCC           | A iniciar      |

## 13. Referências e Inspirações

| Referência                        | O que inspira |
|-----------------------------------|-------------|
| Grim Fandango                     | Estrutura de GDD |
| Silent Hill 2                     | Horror psicológico e culpa |
| What Remains of Edith Finch       | Narrativa através de objetos |
| Amnesia: The Dark Descent         | Mecânica de ameaça sem combate |
| Hellblade: Senua's Sacrifice      | Representação de saúde mental |
| A Arte de Game Design — Jesse Schell | Referência bibliográfica |
| Blasfêmia                         | Inventário apenas visual |

## 14. A Fazer

**Programação**
- Corrigir sistema de carregamento (posição, itens, etc.)
- Melhorar IA da Sombra
- Integrar backend completo
- Implementar coletáveis persistentes e lógica dos endings

**Dublagem e Áudio**
- Gravar roteiros completos (Laura, Pai, Mãe, Hannah, Ryan)
- Aplicar efeito de fita cassete

**Modelagem e Visual**
- Finalizar props e animação da Sombra
- Aplicar shaders VHS/PS1 em todos os ambientes

**Narrativa**
- Escrever todas as fitas e cartas
- Definir posicionamento dos coletáveis

**Infraestrutura**
- Hospedagem VPS + banco de dados
- Publicação na Steam

---

**Lost Memories — GDD v2.0.1**  
*Documento sujeito a alterações conforme o desenvolvimento do projeto.*
