/*
 * Formatar Sem Medo — interface e geração do kit de backup.
 * Autor: Guilherme Martins (github.com/gui198gui)
 */
(function () {
  "use strict";
  const D = window.FSM_DATA;
  const $ = (id) => document.getElementById(id);
  const STORE = "fsm-state-v1";

  /* ---------------- Estado (guardado no browser) ---------------- */
  const state = load() || {
    games: [],
    options: { winget: true, programList: true, vscodeExt: true, wifi: true, drivers: false },
    configs: Object.fromEntries(D.configs.map((c) => [c.id, c.checked])),
    folders: Object.fromEntries(D.folders.map((f) => [f.id, f.checked])),
    checks: {},
    custom: [],
  };
  if (!Array.isArray(state.custom)) state.custom = [];

  function load() {
    try { return JSON.parse(localStorage.getItem(STORE)); } catch { return null; }
  }
  function save() {
    try { localStorage.setItem(STORE, JSON.stringify(state)); } catch { /* modo privado */ }
  }

  let toastTimer;
  function toast(msg) {
    const t = $("toast");
    t.textContent = msg;
    t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (t.hidden = true), 4000);
  }

  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  /* ---------------- Navegação entre passos ---------------- */
  function goTo(n) {
    document.querySelectorAll(".panel").forEach((p) => (p.hidden = p.dataset.panel !== String(n)));
    document.querySelectorAll(".step").forEach((s) => {
      s.classList.toggle("active", s.dataset.step === String(n));
      s.classList.toggle("done", Number(s.dataset.step) < n);
    });
    if (n === 4) renderSummary();
    document.querySelector(".steps").scrollIntoView({ behavior: "smooth", block: "start" });
  }
  document.querySelectorAll(".step").forEach((b) => b.addEventListener("click", () => goTo(Number(b.dataset.step))));
  document.querySelectorAll("[data-go]").forEach((b) => b.addEventListener("click", () => goTo(Number(b.dataset.go))));

  /* ---------------- Passo 1: jogos ---------------- */
  const q = $("game-q");
  const sug = $("game-suggest");
  let searchTimer, searchSeq = 0, activeIdx = -1;

  q.addEventListener("input", () => {
    clearTimeout(searchTimer);
    const text = q.value.trim();
    if (text.length < 2) { sug.hidden = true; return; }
    searchTimer = setTimeout(async () => {
      const seq = ++searchSeq;
      try {
        const results = await PCGW.search(text);
        if (seq !== searchSeq) return;
        activeIdx = -1;
        sug.innerHTML = results.length
          ? results.map((r, i) => `<li role="option" data-i="${i}" data-title="${esc(r)}">${esc(r)}</li>`).join("")
          : `<li class="none">Sem resultados. Experimenta o nome em inglês.</li>`;
        sug.hidden = false;
      } catch {
        toast("Não foi possível pesquisar. Verifica a ligação à internet.");
      }
    }, 250);
  });

  q.addEventListener("keydown", (e) => {
    const items = [...sug.querySelectorAll("li[data-title]")];
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      if (!items.length) return;
      e.preventDefault();
      activeIdx = (activeIdx + (e.key === "ArrowDown" ? 1 : -1) + items.length) % items.length;
      items.forEach((li, i) => li.classList.toggle("active", i === activeIdx));
    } else if (e.key === "Enter") {
      e.preventDefault();
      const pick = items[activeIdx] || items[0];
      if (pick) addGame(pick.dataset.title);
    } else if (e.key === "Escape") {
      sug.hidden = true;
    }
  });

  sug.addEventListener("mousedown", (e) => {
    const li = e.target.closest("li[data-title]");
    if (li) { e.preventDefault(); addGame(li.dataset.title); }
  });
  q.addEventListener("blur", () => setTimeout(() => (sug.hidden = true), 150));

  async function addGame(title) {
    sug.hidden = true;
    q.value = "";
    if (state.games.some((g) => g.name.toLowerCase() === title.toLowerCase())) return toast(`${title} já está na lista.`);
    const placeholder = { name: title, loading: true };
    state.games.unshift(placeholder);
    renderGames();
    try {
      const game = await PCGW.fetchGame(title);
      if (state.games.some((g) => g !== placeholder && g.name === game.name)) {
        state.games.splice(state.games.indexOf(placeholder), 1);
        toast(`${game.name} já está na lista.`);
      } else {
        state.games[state.games.indexOf(placeholder)] = game;
        if (!game.items.length) toast(`O PCGamingWiki não tem a localização dos saves de ${game.name} no Windows.`);
      }
    } catch (err) {
      state.games.splice(state.games.indexOf(placeholder), 1);
      toast(err.message || "Erro ao obter o jogo.");
    }
    save();
    renderGames();
  }

  function renderPopular() {
    $("popular").innerHTML = `<span class="chips-label">Populares:</span>` +
      D.popular.map((t) => `<button class="chip" data-title="${esc(t)}">${esc(t.replace(/^The Elder Scrolls V: /, ""))}</button>`).join("");
  }
  $("popular").addEventListener("click", (e) => {
    const b = e.target.closest(".chip");
    if (b) addGame(b.dataset.title);
  });

  function renderGames() {
    const box = $("games");
    $("games-empty").hidden = state.games.length > 0;
    box.innerHTML = state.games.map((g, i) => {
      if (g.loading) return `<article class="game loading"><h4>${esc(g.name)}</h4><p class="note">A procurar no PCGamingWiki…</p></article>`;
      const saves = g.items.filter((it) => it.kind === "saves");
      const cfg = g.items.filter((it) => it.kind === "config");
      const list = (arr) => arr.map((it) => `<li><code>${esc(PCGW.displayPath(it.pattern))}</code></li>`).join("");
      return `
        <article class="game">
          <header>
            <h4>${esc(g.name)}</h4>
            ${g.cloud ? `<span class="badge cloud" title="A Steam também guarda os saves na nuvem">☁ Steam Cloud</span>` : ""}
            ${!g.items.length ? `<span class="badge warn">Sem dados</span>` : ""}
            <button class="icon-btn" data-remove="${i}" aria-label="Remover ${esc(g.name)}">✕</button>
          </header>
          ${saves.length ? `<p class="kind">💾 Saves</p><ul>${list(saves)}</ul>` : ""}
          ${cfg.length ? `<p class="kind">⚙️ Definições</p><ul>${list(cfg)}</ul>` : ""}
          ${!g.items.length ? `<p class="note">O wiki não indica onde ficam os saves no Windows. Se o jogo tiver cloud, não precisas de te preocupar.</p>` : ""}
          ${g.warnings.map((w) => `<p class="note">ℹ️ ${esc(w)}</p>`).join("")}
          <a class="src" href="${esc(g.url)}" target="_blank" rel="noopener">Ver no PCGamingWiki ↗</a>
        </article>`;
    }).join("");
  }
  $("games").addEventListener("click", (e) => {
    const b = e.target.closest("[data-remove]");
    if (!b) return;
    state.games.splice(Number(b.dataset.remove), 1);
    save();
    renderGames();
  });

  /* ---------------- Passo 2: programas e pastas ---------------- */
  function renderOptions() {
    $("configs").innerHTML = D.configs.map((c) => `
      <label class="opt"><input type="checkbox" data-config="${c.id}" ${state.configs[c.id] ? "checked" : ""}>
        <span><b>${esc(c.name)}</b><small>${esc(c.desc)}</small></span></label>`).join("");
    $("folders").innerHTML = D.folders.map((f) => `
      <label class="opt small"><input type="checkbox" data-folder="${f.id}" ${state.folders[f.id] ? "checked" : ""}>
        <span><b>${esc(f.name)}</b></span></label>`).join("");
    document.querySelectorAll("[data-opt]").forEach((el) => (el.checked = !!state.options[el.dataset.opt]));
  }
  document.addEventListener("change", (e) => {
    const el = e.target;
    if (el.dataset.opt) state.options[el.dataset.opt] = el.checked;
    else if (el.dataset.config) state.configs[el.dataset.config] = el.checked;
    else if (el.dataset.folder) state.folders[el.dataset.folder] = el.checked;
    else if (el.dataset.check) { state.checks[el.dataset.check] = el.checked; renderCheckProgress(); }
    else return;
    save();
  });

  /* ---------------- Outras pastas ---------------- */
  const ENV_TOKENS = {
    "%userprofile%": "<userprofile>", "%appdata%": "<appdata>", "%localappdata%": "<localappdata>",
    "%programdata%": "<programdata>", "%public%": "<public>", "%programfiles%": "<programfiles>",
    "%programfiles(x86)%": "<programfilesx86>", "~": "<userprofile>",
  };

  /** Valida e normaliza um caminho escrito pelo utilizador. Devolve { pattern, display } ou uma mensagem de erro. */
  function parseFolder(input) {
    let p = input.trim().replace(/^["']|["']$/g, "").replace(/\//g, "\\").replace(/\\+$/, "");
    if (!p) return "Escreve o caminho de uma pasta.";
    if (/^[a-z]:$/i.test(p)) return "Escolhe uma pasta, não o disco inteiro.";
    const m = p.match(/^(%[a-z()0-9]+%|~)(\\.*)?$/i);
    if (m) {
      const tok = ENV_TOKENS[m[1].toLowerCase()];
      if (!tok) return `Não conheço a variável ${m[1]}.`;
      return { pattern: tok + (m[2] || "") + "\\", display: p };
    }
    if (!/^[a-z]:\\/i.test(p)) return "O caminho deve começar por uma letra de disco (ex: C:\\Projetos) ou por %USERPROFILE%.";
    if (/^[a-z]:\\?$/i.test(p)) return "Escolhe uma pasta, não o disco inteiro.";
    if (/^[a-z]:\\(windows|program files( \(x86\))?)(\\|$)/i.test(p)) return "Essa pasta é do sistema e é reinstalada com o Windows: não precisas de a copiar.";
    if (/[*?"<>|]/.test(p.slice(2))) return "O caminho tem caracteres inválidos.";
    return { pattern: p + "\\", display: p };
  }

  function renderCustom() {
    $("custom-list").innerHTML = state.custom.map((f, i) =>
      `<li><code>${esc(f.display)}</code><button class="icon-btn" type="button" data-custom-remove="${i}" aria-label="Remover ${esc(f.display)}">✕</button></li>`).join("");
  }

  $("custom-form").addEventListener("submit", (e) => {
    e.preventDefault();
    const input = $("custom-path");
    const r = parseFolder(input.value);
    if (typeof r === "string") return toast(r);
    if (state.custom.some((f) => f.pattern.toLowerCase() === r.pattern.toLowerCase())) return toast("Essa pasta já está na lista.");
    state.custom.push(r);
    input.value = "";
    save();
    renderCustom();
  });
  $("custom-list").addEventListener("click", (e) => {
    const b = e.target.closest("[data-custom-remove]");
    if (!b) return;
    state.custom.splice(Number(b.dataset.customRemove), 1);
    save();
    renderCustom();
  });

  /* ---------------- Passo 3: checklist ---------------- */
  const allChecks = D.checklist.flatMap((g) => g.items);
  function renderChecklist() {
    $("checklist").innerHTML = D.checklist.map((g) => `
      <h3>${esc(g.group)}</h3>
      <div class="opts">${g.items.map(([id, text]) => `
        <label class="opt check"><input type="checkbox" data-check="${id}" ${state.checks[id] ? "checked" : ""}><span>${esc(text)}</span></label>`).join("")}
      </div>`).join("");
    renderCheckProgress();
  }
  function renderCheckProgress() {
    const done = allChecks.filter(([id]) => state.checks[id]).length;
    $("check-bar").style.width = `${(done / allChecks.length) * 100}%`;
    $("check-count").textContent = `${done} de ${allChecks.length} confirmados${done === allChecks.length ? " — estás pronto! 🎉" : ""}`;
  }

  /* ---------------- Passo 4: resumo e ZIP ---------------- */
  function buildConfig() {
    return {
      version: 1,
      created: new Date().toISOString(),
      generator: "https://gui198gui.github.io/formatar-sem-medo/",
      games: state.games.filter((g) => !g.loading && g.items.length).map((g) => ({
        name: g.name, appid: g.appid, cloud: g.cloud,
        items: g.items.map((it) => ({ kind: it.kind, pattern: it.pattern })),
      })),
      configs: D.configs.filter((c) => state.configs[c.id]).map((c) => ({ id: c.id, name: c.name, patterns: c.patterns })),
      folders: D.folders.filter((f) => state.folders[f.id]).map((f) => f.id),
      customFolders: state.custom.map((f) => ({ name: f.display.split("\\").filter(Boolean).pop() || f.display, pattern: f.pattern })),
      options: { ...state.options },
    };
  }

  function renderSummary() {
    const cfg = buildConfig();
    const noData = state.games.filter((g) => !g.loading && !g.items.length).length;
    const opts = cfg.options;
    const done = allChecks.filter(([id]) => state.checks[id]).length;
    const rows = [
      [`🎮 <b>${cfg.games.length}</b> jogo(s) com saves e definições${noData ? ` <small>(${noData} sem dados no wiki)</small>` : ""}`, cfg.games.length > 0],
      [`⚙️ <b>${cfg.configs.length}</b> programa(s) com definições: ${cfg.configs.map((c) => esc(c.name)).join(", ") || "nenhum"}`, cfg.configs.length > 0],
      [`📁 Pastas: ${cfg.folders.map((id) => esc(D.folders.find((f) => f.id === id).name)).join(", ") || "nenhuma"}`, cfg.folders.length > 0],
      [`📂 Outras pastas: ${state.custom.map((f) => esc(f.display)).join(", ") || "nenhuma"}`, state.custom.length > 0],
      [`📦 Reinstalar programas com winget`, opts.winget],
      [`📶 Redes Wi-Fi`, opts.wifi],
      [`🔧 Drivers`, opts.drivers],
      [`✅ Checklist de contas: ${done}/${allChecks.length}`, done === allChecks.length ? true : "todo"],
    ];
    $("summary").innerHTML = rows.map(([html, on]) => `<li class="${on === "todo" ? "todo" : on ? "on" : "off"}">${html}</li>`).join("");
  }

  function checklistText() {
    const lines = ["FORMATAR SEM MEDO - CHECKLIST", "Confirma tudo antes de formatar.", ""];
    for (const g of D.checklist) {
      lines.push(g.group.toUpperCase());
      for (const [id, text] of g.items) lines.push(`  [${state.checks[id] ? "x" : " "}] ${text}`);
      lines.push("");
    }
    return lines.join("\r\n");
  }

  const README = [
    "FORMATAR SEM MEDO - Como usar",
    "",
    "1. Copia esta pasta para uma PEN ou DISCO EXTERNO (nunca para o disco que vais formatar).",
    "2. Fecha os jogos e programas e faz duplo clique em FAZER-BACKUP.bat.",
    "   Fica tudo numa pasta Backup_NOMEDOPC_data.",
    "   (Para copiar drivers: botao direito > Executar como administrador.)",
    "3. Confirma que os teus saves estao na pasta Backup_... e revê a CHECKLIST.txt.",
    "4. Formata o PC e instala o Windows.",
    "5. Liga a pen e faz duplo clique em RESTAURAR.bat.",
    "   Vai aparecer a lista dos teus programas: escolhe so os que queres reinstalar.",
    "6. Instala os jogos e corre o RESTAURAR.bat outra vez para os saves que dependem",
    "   da pasta do jogo ou da Steam.",
    "",
    "Se o Windows mostrar 'O Windows protegeu o computador':",
    "   Mais informacoes > Executar mesmo assim.",
    "",
    "Os scripts so COPIAM ficheiros. Nunca apagam nada.",
    "Codigo: https://github.com/gui198gui/formatar-sem-medo",
  ].join("\r\n");

  $("download").addEventListener("click", async () => {
    const btn = $("download");
    btn.disabled = true;
    btn.textContent = "A preparar…";
    try {
      const names = ["backup.ps1", "restaurar.ps1", "comum.ps1", "FAZER-BACKUP.bat", "RESTAURAR.bat"];
      const files = await Promise.all(names.map(async (n) => {
        const r = await fetch(`scripts/${n}`, { cache: "no-cache" });
        if (!r.ok) throw new Error(`Não consegui obter ${n}.`);
        return [n, await r.text()];
      }));
      const zip = new JSZip();
      const folder = zip.folder("FormatarSemMedo");
      for (const [n, text] of files) {
        // PowerShell 5.1 precisa de BOM para ler UTF-8; os .bat usam CRLF
        if (n.endsWith(".ps1")) folder.file(n, "﻿" + text.replace(/\r?\n/g, "\r\n"));
        else folder.file(n, text.replace(/\r?\n/g, "\r\n"));
      }
      folder.file("config.json", JSON.stringify(buildConfig(), null, 2));
      folder.file("CHECKLIST.txt", "﻿" + checklistText());
      folder.file("LEIA-ME.txt", "﻿" + README);
      const blob = await zip.generateAsync({ type: "blob" });
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "FormatarSemMedo.zip";
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(a.href), 10000);
      toast("Kit descarregado! Extrai-o para uma pen ou disco externo.");
    } catch (err) {
      toast(err.message || "Erro ao gerar o ZIP.");
    } finally {
      btn.disabled = false;
      btn.textContent = "⬇ Descarregar kit (ZIP)";
    }
  });

  /* ---------------- Arranque ---------------- */
  state.games = state.games.filter((g) => !g.loading);
  renderPopular();
  renderGames();
  renderOptions();
  renderCustom();
  renderChecklist();

  window.__fsm = { state, buildConfig };
})();
