# Workut — app Flutter

A rede social de quem treina. O app consome a mesma API (.NET / `workutApi`) do
front Angular (`workutFront`), com uma pegada de academia — treinos, séries, PR e
ranking — e referências ao Orkut: depoimentos, recados e as "vibes" do perfil.

## O que já está implementado

| Área | Telas / recursos |
| --- | --- |
| Conta | Login (JWT), cadastro, troca de senha, logout automático no 401 |
| Feed | Posts de texto e **card de treino** (volume, séries, exercícios, duração, PRs), foto, curtir, comentar, apagar o próprio post |
| Treinos | Criar/renomear/excluir treino, adicionar e remover exercícios, catálogo com busca e criação de exercício |
| Execução | **Sessão de treino**: cronômetro, exercício abre no lugar para registrar a série, volume ao vivo no rodapé e tela de treino finalizado com PRs |
| Histórico | PR (maior carga), 1RM estimado, melhor série, volume total e linha do tempo por dia |
| Social | Seguir / aceitar pedido / deixar de seguir, busca de pessoas, perfil com volume de 7 dias, treinos no mês, recordes e sequência |
| Orkut mode | Depoimentos (com curtida), recados em formato de conversa, vibes do perfil (Fera, Parceiro, Shape, Motivador, Focado) |
| Ranking | Ranking geral por score relativo ao peso e altura |

## Identidade visual

A paleta, a marca e as formas são as mesmas do front Angular
(`workutFront`). Os tokens vivem em [lib/core/theme.dart](lib/core/theme.dart)
(`WorkutColors` / `WorkutTheme`) e espelham `src/styles/_workut-tokens.scss`
do front — mudou em um, mude no outro. O sistema completo está documentado
em `DESIGN.md`, na raiz do workutFront.

Resumo: vermelho `#ED1C24` do logo para ação e curtida, ink `#1B2430` para
texto e superfícies escuras, dourado `#F5A524` só para PR e ranking, cartões
brancos de raio 20 com borda fina e sem sombra, tipografia Roboto.

## Estrutura

```
lib/
  core/       api_constants, api_client (Bearer + erros), session (JWT), theme, formatters
  models/     app_user, feed, workout, social
  services/   auth, user, feed, workout, social, photo
  screens/    login, register, home_shell, feed, composer, workouts, plan_detail,
              workout_session, workout_summary, exercise_session,
              exercise_history, exercise_catalog, people, profile,
              edit_profile, scrap_chat, ranking
  widgets/    common, brand, post_card, comments_sheet
```

## Rodando

```bash
flutter pub get
```

```bash
flutter run
```

A URL da API fica em `lib/core/api_constants.dart` (mesma constante usada pelo
`AppConstants.ts` do workutFront).

## Detalhes de integração que valem lembrar

- **Usuário logado**: a API embute o usuário serializado na claim `aud` do JWT.
  O app decodifica o token no login, igual ao front.
- **Foto de perfil**: fica no campo `hometown` do `UserVO` (herança do projeto
  original). O app expõe isso como `avatarUrl`.
- **Feed**: `FeedPosts/v1/GetById/{id}` devolve tudo pronto — imagem, tipo,
  contadores de curtida e comentário e o resumo do treino. Requer a migration
  `V1_0_4` aplicada no banco.
- **Altura**: gravada em metros (ex.: `1,75`), como o cadastro do front faz.
- **Datas**: enviadas no mesmo formato do front (horário de Brasília sem fuso),
  para o filtro diário de `ExerciseDaillys/v1/GetToList` bater.
