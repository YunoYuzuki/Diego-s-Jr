# 🎮 Lost Memories — *Memórias Perdidas*

> **Game Design Document (GDD) — Versão 1.0 — 2026**

Motor: **Godot 3.6.2** | Plataforma: **PC (Windows)**

**Equipe:** Tadeu • Matheus • Mariane • Pedro C • Pedro G • Luiz A

---

## 📋 Visão Geral do Projeto

| Campo | Descrição |
|---|---|
| Título | Lost Memories *(Memórias Perdidas)* |
| Gênero | Horror Psicológico / Exploração Narrativa |
| Motor | Godot 3.6.2 stable |
| Plataforma | PC (Windows) |
| Perspectiva | Primeira Pessoa (FPS) |
| Estética Visual | Low-poly estilo PS1 |
| Duração estimada | 30 a 60 minutos por partida |
| Número de endings | 2 (bom e ruim) |
| Classificação indicativa | 16+ *(temas de morte, drogas, saúde mental)* |

---

## 📖 Sinopse

Laura está morta.

Ela acorda na casa de sua infância sem nenhuma memória de quem foi ou como chegou ali — apenas se lembrando da casa em que está. O quarto que deveria ser o dela está completamente vazio; ela saiu de casa anos atrás e nunca mais voltou.

Espalhadas pela casa há fitas cassete e cartas que contam, aos poucos, a história de sua vida: a morte do pai no seu aniversário de 18 anos, a culpa imposta pela mãe, a fuga, as drogas e, por fim, a overdose que induziu conscientemente num surto depressivo.

Enquanto coleta essas memórias, uma sombra a persegue pelos cômodos — uma manifestação da culpa e do peso que carregou em vida. O destino de Laura depende de como ela enfrenta — ou foge de — sua própria história.

---

## 📚 Sumário

- [História Detalhada](#-história-detalhada)
- [Personagens](#-personagens)
- [Core Loop](#-core-loop)
- [Mecânicas de Jogo](#️-mecânicas-de-jogo)
- [Interface (HUD)](#️-interface-hud)
- [Ambientes](#-ambientes)
- [Identidade Visual e Sonora](#-identidade-visual-e-sonora)
- [Backend e Sistema Online](#-backend-e-sistema-online)
- [Divisão de Tarefas](#-divisão-de-tarefas)
- [Cronograma](#-cronograma)
- [Referências e Inspirações](#-referências-e-inspirações)

---

## 🕯️ História Detalhada

### Protagonista

| Atributo | Descrição |
|---|---|
| Nome | Laura |
| Condição | Morta — presa no limbo na forma de sua casa de infância |
| Memória | Completamente apagada no início do jogo |
| Personalidade | Sensível, culpada, isolada, mas com momentos de leveza na infância *(revelada via coletáveis)* |
| Dublagem | Mariane |

### Linha do Tempo da História

1. Infância de Laura na casa — memórias felizes *(reveladas via cartas antigas)*
2. Pai de Laura adoece gravemente
3. Aniversário de 18 anos de Laura: o pai morre nesse dia
4. A mãe culpa Laura por não ter usado o dinheiro da festa nos medicamentos do pai
5. Laura sai de casa e corta contato com a mãe
6. Laura começa a usar drogas como escapismo
7. Num surto depressivo intenso, Laura induz uma overdose propositalmente
8. Laura morre e acorda no limbo — a casa de infância — sem memória alguma

### Estrutura Narrativa

A história é contada de forma **não-linear**, reconstruída pelo jogador através dos coletáveis. As fitas cassete revelam momentos emocionais e íntimos (a voz do pai, mensagens deixadas por Laura para si mesma). As cartas revelam os eventos objetivos da história.

O jogador monta o quebra-cabeça da vida de Laura progressivamente, chegando ao final com a imagem completa de quem ela foi.

---

## 👥 Personagens

| Nome | Papel | Dublagem | Observações |
|---|---|---|---|
| Laura | Protagonista | Mariane | Narradora interna; reage aos ambientes |
| Pai de Laura | Personagem ausente | Tadeu *(a confirmar)* | Presente apenas nas fitas cassete |
| A Sombra | Ameaça / Antagonista | Sem fala | Manifestação da culpa de Laura |
| Mãe de Laura | Personagem ausente | Sem dublagem | Mencionada nas cartas; nunca aparece fisicamente |

---

## 🔄 Core Loop

```
EXPLORAR → ENCONTRAR COLETÁVEL → RECEBER MEMÓRIA → EXPLORAR NOVAMENTE
```

O jogador:
- Explora os cômodos da casa em primeira pessoa
- Encontra fitas cassete escondidas em locais difíceis de achar
- Encontra cartas e bilhetes espalhados
- Ao coletar, recebe um fragmento da memória de Laura (áudio ou texto)
- A sombra aparece ocasionalmente, criando tensão e urgência
- Ao encontrar a fita cassete, pode salvar o progresso
- Com memórias suficientes, desbloqueia o ending correspondente

---

## 🎮 Mecânicas de Jogo

### 6.1 Movimentação

| Mecânica | Detalhe |
|---|---|
| Andar | WASD — velocidade padrão de caminhada |
| Correr | Shift — consome stamina; barra de stamina visível no HUD |
| Câmera | Mouse — FPS com head bob, tilt e sway suaves |

### 6.2 Interação

- Raycast em primeira pessoa detecta objetos no grupo `interagivel`
- Crosshair muda de aparência ao mirar em objeto interagível
- Tecla `E` (ou clique) para interagir
- Objetos coletados desaparecem da cena imediatamente

### 6.3 Coletáveis

| Tipo | Quantidade prevista | Função |
|---|---|---|
| Fitas Cassete | ~8 a 12 | Checkpoint de save + fragmento de memória em áudio |
| Cartas / Bilhetes | ~10 a 15 | Fragmentos de memória em texto; revelam eventos da história |
| Fotos | ~5 | Memórias visuais; complementam a narrativa sem texto |

### 6.4 Sistema de Save — Fitas Cassete

O jogo é salvo automaticamente quando o jogador coleta uma fita cassete. Uma notificação na tela exibe *"Nova fita encontrada"* com fade in/out. As fitas são intencionalmente difíceis de localizar para estender o tempo de exploração e aumentar a tensão.

O jogo também é salvo automaticamente a cada 5 minutos, exibindo no canto superior direito a mensagem *"salvando automaticamente…"*. O intervalo de autosave ainda pode ser ajustado futuramente.

### 6.5 Lanterna

A lanterna é encontrada como item no início do jogo. Sem ela, o jogador não consegue ver nos ambientes mais escuros. Ela é adicionada dinamicamente à câmera do jogador via `SpotLight` ao ser coletada.

### 6.6 A Sombra

| Situação | Comportamento |
|---|---|
| Aparição aleatória | Surge em corredores e cômodos à distância, observando |
| Ao detectar o jogador | Apaga a lanterna temporariamente |
| Efeito sonoro | Som de passos e respiração pesada que desorientam |
| Contato direto | Teleporta o jogador para o último ponto de save (fita cassete) |
| Significado narrativo | Representa a culpa e o peso emocional que Laura carregou |

### 6.7 Endings

| Ending | Condição | Descrição |
|---|---|---|
| ✅ **Paz** *(Ending Bom)* | Coletar todas as fitas e cartas | Laura reconstrói sua memória completa, aceita sua história sem culpa e parte em paz. Cena final: o quarto vazio se preenche com luz e desaparece. |
| 🔁 **Loop Eterno** *(Ending Ruim)* | Zerar sem coletar todos os coletáveis | Laura não consegue aceitar o que viveu. A casa se reinicia do zero — ela está presa repetindo o mesmo ciclo para sempre, sem paz e sem saída. |

---

## 🖥️ Interface (HUD)

- **Barra de stamina:** aparece ao correr, some após alguns segundos parada
- **Crosshair central:** muda de aparência próximo a objetos interagíveis
- **Sem minimapa** — o jogador deve explorar organicamente
- **Sem inventário manipulável** — os coletáveis são experienciados, não gerenciados *(inventário visível apenas para consulta)*

---

## 🏠 Ambientes

| Cômodo | Descrição | Coletáveis esperados |
|---|---|---|
| Hall de entrada | Primeiro ambiente; escuro, porta trancada | 1 carta |
| Sala de estar | Móveis velhos cobertos de pó; TV estática | 1 fita, 1 carta |
| Cozinha | Louça suja, calendário parado numa data | 1 carta, 1 foto |
| Quarto do pai | Cama desfeita, remédios na mesa de cabeceira | 2 fitas, 2 cartas |
| Quarto de Laura (vazio) | Completamente vazio; piso marcado onde havia móveis | 1 carta *(escondida no assoalho)* |

---

## 🎨 Identidade Visual e Sonora

### Visual

- Estética **low-poly** com paleta de cores dessaturada *(cinzas, verdes escuros, marrons)*
- Texturas com filtro **Nearest** e Mipmaps desativados — efeito PS1
- Shaders pós-processamento: **filtro VHS** + câmera anos 90/2000 ativo
- Iluminação ambiente levemente fraca

### Sonoro

- Fitas cassete reproduzem áudio com **efeito de fita degradada**
- A Sombra tem tema sonoro próprio: frequências graves e respiração
- **Dublagem de Laura** (Mariane): reações ao ambiente, leitura de cartas em voz alta
- **Voz do pai** nas fitas cassete (Tadeu — a confirmar)

---

## 🌐 Backend e Sistema Online

### Arquitetura

| Componente | Tecnologia | Responsável |
|---|---|---|
| Game Client | Godot 3.6.2 | Tadeu |
| Backend / API | Node.js + Express | Tadeu |
| Banco de Dados | A definir *(PostgreSQL ou MongoDB)* | Tadeu |
| Hospedagem | A definir | Tadeu |

### Funcionalidades Online

| Funcionalidade | Descrição |
|---|---|
| Login / Cadastro | O jogador cria uma conta com nome de usuário e senha |
| Perfil do jogador | Armazena dados da partida mais recente e do melhor resultado |
| Ranking Global | Lista os jogadores com melhor desempenho |
| Dados enviados | Nome, tempo total de jogo, coletáveis encontrados, ending obtido |

### Fluxo de Dados

- O save local (fitas cassete) funciona **independentemente** do backend
- Ao zerar o jogo, o Godot envia os dados via `HTTPRequest POST` para a API
- A API valida e salva no banco de dados
- O ranking pode ser consultado no menu principal do jogo

---

## 🧑‍💻 Divisão de Tarefas

| Membro | Função Principal | Tarefas |
|---|---|---|
| Tadeu | Programação + Direção | Todo o código em Godot (movimentação, interação, shaders, saves, HTTPRequest); possível dublagem do pai |
| Matheus | Modelagem 3D | Todos os modelos dos ambientes, props, coletáveis e a sombra |
| Mariane | Dublagem | Voz da protagonista Laura — reações e leitura de cartas |
| Pedro C | Documentação | GDD atualizado e documentação técnica do TCC |
| Pedro G | Game Design / Ideias | Contribuição com ideias de design, puzzles e narrativa |
| Luiz A | Game Design / Ideias | Contribuição com ideias de design, puzzles e narrativa |

---

## 📅 Cronograma

| Fase | Atividades | Status |
|---|---|---|
| Fase 1 — Pré-produção | GDD finalizado, divisão de tarefas, definição do backend | 🟡 Em andamento |
| Fase 2 — Prototipagem | Level layout da casa, mecânicas básicas, primeiro coletável | 🟡 Parcialmente pronto |
| Fase 3 — Produção | Todos os ambientes, coletáveis, sombra, dublagem, backend integrado | ⚪ A iniciar |
| Fase 4 — Polimento | Shaders, sons, ajuste de dificuldade dos esconderijos das fitas | ⚪ A iniciar |
| Fase 5 — Entrega | Build final, documentação TCC, apresentação | ⚪ A iniciar |

---

## 🎯 Referências e Inspirações

| Referência | O que inspira no projeto |
|---|---|
| Grim Fandango *(LucasArts)* | Estrutura de GDD fornecida pelo professor como modelo |
| Silent Hill 2 | Horror psicológico com antagonista como manifestação de culpa/trauma |
| What Remains of Edith Finch | Narrativa fragmentada contada por objetos e ambientes |
| Amnesia: The Dark Descent | Mecânica de sombra como ameaça sem combate |
| Hellblade: Senua's Sacrifice | Representação respeitosa de saúde mental como tema central |
| A Arte de Game Design — Jesse Schell | Referência bibliográfica fornecida pelo professor |
| Blasfêmia | Jogo brasileiro; inventário não manipulável, somente visível |

---

*Lost Memories — GDD v1.0 | Documento sujeito a alterações conforme o desenvolvimento do projeto.*
