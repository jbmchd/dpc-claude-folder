# DPC — Padrões assíncronos em componentes Vue

> Regras para carregamento assíncrono em `mounted()` e dependências entre chamadas no frontend Vue 2.
> Aplicar em `DPC/src/app/**/*.vue`, principalmente em telas/modais com selects alimentados por API.

Ver também: [dpc-convencoes.md](dpc-convencoes.md)

---

## 1. Problema recorrente: race condition em modal de edição

Cenário típico do `ModalSalvar`:

1. `mounted()` dispara `buscarLicencas()` (popula `<select>` de licenças) e, se estiver em modo edição, `buscarProjeto()` (carrega os dados do registro).
2. `buscarProjeto()` volta antes de `buscarLicencas()`.
3. O valor de `form.licenca` referencia uma licença que ainda não está no array `licencas`.
4. O código cai no fallback "licença não encontrada" e o dropdown exibe o **código** em vez do **nome do cliente**.

Esse bug apareceu em #3057/#3064 e só foi identificado depois de instrumentar `console.log`. A regra abaixo evita toda essa classe de erro.

---

## 2. Regra: no `mounted()`, encadear dependências explicitamente

Quando o carregamento do registro depende de listas que alimentam selects, **aguardar as listas antes de buscar o registro**.

```js
mounted() {
  const dependencias = Promise.all([
    this.buscarLicencas(),
    this.buscarSegmentos(),
    this.buscarRepositorios(),
  ]);

  if (this.codProjeto) {
    dependencias.then(() => this.buscarProjeto());
  }
}
```

Requisitos:

- Cada método de carregamento **retorna a Promise** (`return dpcAxios.connection().get(...)`), não apenas dispara e esquece.
- Listas independentes entram em `Promise.all`; dependências reais (uma lista que alimenta outra) usam `.then` encadeado.
- Nunca confiar em "vai chegar a tempo" baseado em ordem de chamada.

---

## 3. Fallbacks preservam o shape da lista

Quando um valor do registro não existe na lista carregada (licença inativa, recém-criada etc.), o fallback deve inserir um objeto com **o mesmo shape** dos itens vindos da API. Caso contrário o template quebra em `{{ item.campo }}`.

```js
// Lista real vem com { licenca, cliente }
// ❌ não fazer
this.licencas.unshift({ licenca: d.licenca });

// ✅ manter o shape
this.licencas.unshift({ licenca: d.licenca, cliente: d.licenca });
```

O fallback deve usar o próprio valor como `cliente` (ou campo equivalente) até que o usuário troque para uma opção válida.

---

## 4. Template com fallback visual

Para selects que podem receber um valor fora da lista (legacy data), usar `||` no label:

```vue
<option v-for="lic in licencas" :key="lic.licenca" :value="lic.licenca">
  {{ lic.cliente || lic.licenca }}
</option>
```

Isso garante que mesmo um fallback sem dados descritivos renderize algo útil.

---

## 5. Tratamento de erro da API

Métodos de carregamento **sempre** tratam `response.data.error != 0` — não assumir sucesso:

```js
buscarLicencas() {
  return dpcAxios
    .connection()
    .get(process.env.ENDERECO_APIDPC + "ti/projetos-edi/licencas")
    .then((response) => {
      if (response.data.error == 0) {
        this.licencas = response.data.data;
      } else {
        console.warn("[licencas] API retornou erro:", response.data.message);
      }
    })
    .catch((e) => console.error("[licencas] falha na requisição:", e));
}
```

`console.warn` com prefixo `[nome-da-lista]` facilita diagnóstico posterior no DevTools.

---

## 6. Checklist ao criar modal com dependências assíncronas

- [ ] Todos os métodos de `buscarX()` retornam a Promise.
- [ ] `mounted()` espera dependências antes de carregar o registro em modo edição.
- [ ] Fallbacks de item fora da lista mantêm o shape completo.
- [ ] Template usa `a || b` em labels onde cabe fallback visual.
- [ ] Cada `buscar` trata `error != 0` e `.catch`.
