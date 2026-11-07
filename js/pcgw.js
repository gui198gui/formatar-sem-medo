/*
 * Ligação ao PCGamingWiki (MediaWiki API, CORS aberto) e leitura da secção
 * "Game data" de cada jogo: localização dos saves e das definições no Windows.
 */
(function () {
  "use strict";
  const API = "https://www.pcgamingwiki.com/w/api.php";

  // Variáveis {{p|...}} do PCGamingWiki -> variáveis que os scripts entendem
  const TOKENS = {
    "game": "<game>",
    "uid": "<uid>",
    "steam": "<steam>",
    "steamlibrary": "<steamlibrary>",
    "uplay": "<ubisoftconnect>",
    "ubisoftconnect": "<ubisoftconnect>",
    "hkcu": "<hkcu>",
    "hkey_current_user": "<hkcu>",
    "hklm": "<hklm>",
    "hkey_local_machine": "<hklm>",
    "wow64": "<wow64>",
    "username": "<username>",
    "userprofile": "<userprofile>",
    "userprofile\\documents": "<documents>",
    "appdata": "<appdata>",
    "userprofile\\appdata\\locallow": "<locallow>",
    "localappdata": "<localappdata>",
    "temp": "<temp>",
    "public": "<public>",
    "allusersprofile": "<programdata>",
    "programdata": "<programdata>",
    "programfiles": "<programfiles>",
    "windir": "<windir>",
    "syswow64": "SysWOW64",
  };

  // Como mostrar cada variável ao utilizador
  const DISPLAY = {
    "<game>": "[pasta do jogo]", "<uid>": "[id]", "<steam>": "[Steam]", "<steamlibrary>": "[biblioteca Steam]",
    "<ubisoftconnect>": "[Ubisoft Connect]", "<hkcu>": "HKEY_CURRENT_USER", "<hklm>": "HKEY_LOCAL_MACHINE",
    "<wow64>": "WOW6432Node", "<username>": "%USERNAME%", "<userprofile>": "%USERPROFILE%",
    "<documents>": "Documentos", "<appdata>": "%APPDATA%", "<locallow>": "%USERPROFILE%\\AppData\\LocalLow",
    "<localappdata>": "%LOCALAPPDATA%", "<temp>": "%TEMP%", "<public>": "%PUBLIC%", "<programdata>": "%PROGRAMDATA%",
    "<programfiles>": "%PROGRAMFILES%", "<programfilesx86>": "%PROGRAMFILES(X86)%", "<windir>": "%WINDIR%",
  };

  // Plataformas cujos caminhos se aplicam a um PC com Windows
  const PLATFORMS = /^(windows|steam|gog\.com|epic games store|epic games launcher|ubisoft connect|uplay|origin|ea app|battle\.net)$/i;

  function displayPath(pattern) {
    return pattern.replace(/<[a-z]+>/g, (t) => DISPLAY[t] || t);
  }

  function stripMarkup(text) {
    return text
      .replace(/<!--[\s\S]*?-->/g, "")
      .replace(/<ref[^>]*\/>/gi, "")
      .replace(/<ref[^>]*>[\s\S]*?<\/ref>/gi, "");
  }

  /** Encontra todas as chamadas a um template, respeitando chavetas aninhadas. */
  function findTemplates(text, name) {
    const out = [];
    const re = new RegExp("\\{\\{\\s*" + name.replace(/[/]/g, "\\/") + "\\s*\\|", "gi");
    let m;
    while ((m = re.exec(text))) {
      let depth = 2;
      let i = m.index + 2;
      while (i < text.length && depth > 0) {
        if (text.startsWith("{{", i)) { depth += 2; i += 2; continue; }
        if (text.startsWith("}}", i)) { depth -= 2; i += 2; continue; }
        i++;
      }
      const inner = text.slice(m.index + 2, i - 2);
      out.push(splitTopLevel(inner).slice(1)); // remove o nome do template
      re.lastIndex = i;
    }
    return out;
  }

  /** Divide por "|" apenas fora de {{ }}. */
  function splitTopLevel(s) {
    const parts = [];
    let depth = 0, cur = "";
    for (let i = 0; i < s.length; i++) {
      if (s.startsWith("{{", i)) { depth++; cur += "{{"; i++; continue; }
      if (s.startsWith("}}", i)) { depth--; cur += "}}"; i++; continue; }
      if (s[i] === "|" && depth === 0) { parts.push(cur); cur = ""; continue; }
      cur += s[i];
    }
    parts.push(cur);
    return parts.map((p) => p.trim());
  }

  /** Converte um caminho do wiki num padrão dos scripts. Devolve null se não for suportado. */
  function toPattern(raw) {
    let ok = true;
    const p = raw.replace(/\{\{\s*p\s*\|\s*([^}]+?)\s*\}\}/gi, (_, key) => {
      const t = TOKENS[key.trim().toLowerCase()];
      if (!t) ok = false;
      return t || "";
    }).trim();
    if (!ok || !p || /\{\{|\}\}|\[\[|<br/i.test(p)) return null;
    if (!/^<[a-z]+>/.test(p)) return null; // tem de começar numa pasta conhecida
    return p;
  }

  function parseGame(title, wikitext) {
    const text = stripMarkup(wikitext);
    const appidMatch = text.match(/\|\s*steam appid\s*=\s*(\d+)/i);
    const cloudMatch = text.match(/\|\s*steam cloud\s*=\s*(\w+)/i);
    const items = [];
    const warnings = new Set();
    const seen = new Set();

    for (const kind of ["saves", "config"]) {
      for (const args of findTemplates(text, "Game data/" + kind)) {
        const platform = (args[0] || "").trim();
        if (!PLATFORMS.test(platform)) continue;
        for (const raw of args.slice(1)) {
          if (!raw) continue;
          const pattern = toPattern(raw);
          if (!pattern) continue;
          const key = kind + "|" + pattern.toLowerCase();
          if (seen.has(key)) continue;
          seen.add(key);
          items.push({ kind, pattern, platform });
          if (pattern.includes("<game>") && !appidMatch) warnings.add("Alguns ficheiros estão na pasta do jogo: só os encontramos automaticamente em jogos da Steam.");
          if (pattern.startsWith("<hklm>")) warnings.add("Algumas definições estão no registo do sistema (HKLM): o restauro pode pedir administrador.");
        }
      }
    }
    return {
      name: title,
      appid: appidMatch ? appidMatch[1] : null,
      cloud: cloudMatch ? /^true$/i.test(cloudMatch[1]) : false,
      items,
      warnings: [...warnings],
      url: "https://www.pcgamingwiki.com/wiki/" + encodeURIComponent(title.replace(/ /g, "_")),
    };
  }

  async function api(params) {
    const url = API + "?" + new URLSearchParams({ ...params, format: "json", origin: "*" });
    const res = await fetch(url);
    if (!res.ok) throw new Error("O PCGamingWiki não respondeu (" + res.status + ").");
    return res.json();
  }

  async function search(q) {
    const data = await api({ action: "opensearch", search: q, limit: "8", namespace: "0" });
    return data[1] || [];
  }

  async function fetchGame(title) {
    const data = await api({ action: "parse", page: title, prop: "wikitext", redirects: "1" });
    if (data.error) throw new Error("Não encontrei \"" + title + "\" no PCGamingWiki.");
    return parseGame(data.parse.title, data.parse.wikitext["*"]);
  }

  window.PCGW = { search, fetchGame, parseGame, toPattern, displayPath, findTemplates };
})();
