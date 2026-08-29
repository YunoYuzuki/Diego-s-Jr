# Como contribuir

Combinado de trabalho da equipe. A regra geral: **a `main` sempre abre e sempre
roda.** Se um clone novo da `main` não abre no Godot, isso é o problema mais
urgente do projeto, na frente de qualquer funcionalidade.

---

## Antes de tudo: nunca use "Add files via upload"

Subir arquivo pela interface web do GitHub **substitui, não mescla**. Ela também
não sobe pasta com estrutura, o que leva a zipar diretórios, e zip no Git não
tem diff, não tem histórico útil, e reenvia inteiro a cada mudança.

Já aconteceu neste repositório: em quatro minutos o `project.godot`, os 482
assets, as cenas, o ícone, o `.gitignore` e o GDD foram apagados por esse
caminho. O código era bom; o jeito de subir é que destruiu o repositório.

**Use `git` pela linha de comando ou pela IDE. Sempre.**

---

## Preparando a máquina

```bash
git clone https://github.com/YunoYuzuki/Diego-s-Jr.git
cd Diego-s-Jr
```

**Godot 3.6.3**, não 4.x. Abrir este projeto no Godot 4 oferece converter para
4.x, e a conversão é destrutiva. Sintaxe do Godot 4 (`@export`, `@onready`,
`StaticBody3D`, `Node3D`) não dá erro sutil aqui: **trava o import do projeto
inteiro.**

Backend:

```bash
cd backend
npm install
cp .env.example .env    # preencha JWT_SECRET
npm start
```

---

## O ciclo de trabalho

```
main ─────●─────────────●──────────●────►  sempre funcionando
           \           /
            ●──●──●───/   feature/nome-da-tarefa
```

1. **Atualize antes de começar**

   ```bash
   git checkout main
   git pull
   ```

2. **Crie uma branch pra sua tarefa**

   ```bash
   git checkout -b feature/ranking-no-menu
   ```

   Prefixos: `feature/` para funcionalidade nova, `fix/` para correção,
   `docs/` para documentação, `chore/` para organização.

   Uma branch por tarefa. Branch que faz três coisas diferentes é impossível de
   revisar e de reverter.

3. **Commite em pedaços que fazem sentido**

   Mensagem em português, no imperativo, dizendo *o quê* e, quando não for
   óbvio, *por quê*:

   ```
   Corrigir desempate do ranking quando playtime é zero

   Jogador com tempo zero e itens coletados ficava em primeiro.
   GREATEST(playtime, 1) evita isso e a divisão por zero.
   ```

   Sem assinatura de ferramenta, sem "commit final", sem "ajustes".

4. **Antes de abrir o PR, teste um clone limpo**

   Esta é a etapa que teria evitado o maior problema que já tivemos:

   ```bash
   cd /tmp
   git clone -b sua-branch https://github.com/YunoYuzuki/Diego-s-Jr.git teste
   cd teste
   # abra no Godot 3.6.3 e rode
   ```

   Se não abrir aí, não vai abrir na máquina de ninguém. **Funcionar na sua
   máquina não é evidência de nada** — a sua máquina tem arquivos que o
   repositório não tem.

5. **Abra o Pull Request**

   Descreva o que muda e como testar. Peça revisão. Só faça merge depois que
   alguém olhar.

---

## Assets: o erro mais fácil de cometer

Quando você adicionar uma imagem, um som, um modelo ou uma fonte, **o arquivo
precisa ser commitado junto com a cena que o usa.**

Já tivemos 41 arquivos referenciados por cenas e ausentes do repositório —
áudio, vídeo, fontes e cenas de pickup. Funcionava na máquina de quem criou e
não funcionava em nenhuma outra.

Antes de commitar, confira o que ficou de fora:

```bash
git status
git status --ignored     # mostra o que o .gitignore está engolindo
```

Se um asset seu aparece como ignorado e você precisa dele versionado, avise a
equipe em vez de editar o `.gitignore` sozinho.

Os arquivos `*.import` **ao lado de cada asset** são versionados: eles guardam
o identificador que as cenas usam. A pasta `.import/` na raiz **não** é — é
cache, a engine reconstrói sozinha.

---

## Nunca commitar

| | Motivo |
|---|---|
| `.import/` | Cache da engine. São centenas de MB que se regeneram sozinhos. |
| `node_modules/` | Reinstala com `npm install`. |
| `.env` | Contém segredo. Use o `.env.example` como modelo. |
| `*.zip`, `*.rar` | Sem diff, sem histórico. Suba os arquivos soltos. |
| Builds (`*.pck`, `*.exe`, `*.apk`, `*.dmg`) | Gerados a partir do código. |
| Arquivo pessoal | Já entrou música pessoal no repositório por acidente. |

---

## Contrato da API

Jogo e servidor já foram escritos, uma vez, contra especificações diferentes: o
jogo chamava `POST /api/auth/login` e o servidor respondia em `POST /api/login`.
Nenhum dos dois estava errado sozinho — faltava um documento dizendo qual era o
certo.

**Mudou rota, corpo ou resposta? Documente no mesmo commit da mudança.** Um
contrato desatualizado é pior que contrato nenhum, porque as pessoas confiam
nele.

---

## Revisando o PR de alguém

Revisão não é procurar erro, é a segunda cabeça que o autor não tem. Vale
perguntar:

- Isso abre num clone limpo?
- Os assets novos foram commitados junto?
- Tem algum `.zip` ou segredo entrando sem querer?
- A sintaxe é Godot 3.6, não 4.x?
- Se mexeu na API, o contrato foi atualizado?

Aprovar sem ler não ajuda ninguém. Pedir mudança não é crítica pessoal.
