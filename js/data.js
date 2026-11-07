/* Dados fixos da app: definições de programas, pastas, checklist e jogos populares. */
window.FSM_DATA = {
  // Padrões com as mesmas variáveis que os scripts entendem (<appdata>, <documents>, ...)
  configs: [
    { id: "vscode", name: "VS Code", desc: "Definições, atalhos e snippets", checked: true,
      patterns: ["<appdata>\\Code\\User\\settings.json", "<appdata>\\Code\\User\\keybindings.json", "<appdata>\\Code\\User\\snippets\\"] },
    { id: "terminal", name: "Windows Terminal", desc: "Perfis, cores e atalhos", checked: true,
      patterns: ["<localappdata>\\Packages\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\LocalState\\settings.json"] },
    { id: "pwsh", name: "Perfis do PowerShell", desc: "Os teus scripts de arranque do PowerShell", checked: true,
      patterns: ["<documents>\\PowerShell\\", "<documents>\\WindowsPowerShell\\"] },
    { id: "git", name: "Git", desc: "O teu .gitconfig (nome, email, aliases)", checked: true,
      patterns: ["<userprofile>\\.gitconfig"] },
    { id: "ssh", name: "Chaves SSH", desc: "⚠️ São chaves privadas: guarda a pen em segurança", checked: false,
      patterns: ["<userprofile>\\.ssh\\"] },
    { id: "obs", name: "OBS Studio", desc: "Cenas, fontes e perfis de gravação/stream", checked: true,
      patterns: ["<appdata>\\obs-studio\\basic\\", "<appdata>\\obs-studio\\global.ini"] },
    { id: "steamuser", name: "Steam: screenshots e definições locais", desc: "Pasta userdata (configs de comando, screenshots)", checked: true,
      patterns: ["<steam>\\userdata\\"] },
    { id: "bookmarks", name: "Favoritos dos browsers", desc: "Chrome, Edge e Brave (se não usares a sincronização)", checked: false,
      patterns: [
        "<localappdata>\\Google\\Chrome\\User Data\\Default\\Bookmarks",
        "<localappdata>\\Microsoft\\Edge\\User Data\\Default\\Bookmarks",
        "<localappdata>\\BraveSoftware\\Brave-Browser\\User Data\\Default\\Bookmarks"] },
    { id: "npp", name: "Notepad++", desc: "Definições, temas e sessão", checked: false,
      patterns: ["<appdata>\\Notepad++\\"] },
    { id: "afterburner", name: "MSI Afterburner", desc: "Perfis de overclock e curvas das ventoinhas", checked: false,
      patterns: ["<programfilesx86>\\MSI Afterburner\\Profiles\\"] },
  ],

  folders: [
    { id: "desktop", name: "Ambiente de trabalho", checked: true },
    { id: "documents", name: "Documentos", checked: true },
    { id: "pictures", name: "Imagens", checked: true },
    { id: "videos", name: "Vídeos", checked: false },
    { id: "music", name: "Música", checked: false },
    { id: "downloads", name: "Transferências", checked: false },
  ],

  checklist: [
    { group: "Contas e acessos", items: [
      ["ms", "Sei o email e a palavra-passe da conta Microsoft (a licença do Windows costuma estar ligada a ela)"],
      ["bitlocker", "Se o disco tiver BitLocker, guardei a chave de recuperação (aka.ms/myrecoverykey)"],
      ["browser", "Ativei a sincronização do browser ou exportei as palavras-passe para um gestor de passwords"],
      ["2fa", "A app de autenticação (2FA) está no telemóvel e tenho os códigos de recuperação"],
      ["email", "Consigo entrar no meu email principal: é por lá que se recuperam as outras contas"],
    ]},
    { group: "Jogos", items: [
      ["steam", "Sei a palavra-passe da Steam e tenho o Steam Guard no telemóvel"],
      ["launchers", "Sei as palavras-passe da Epic, Battle.net, EA, Ubisoft, Riot e outras que use"],
      ["discord", "Discord: tenho a palavra-passe e os códigos de backup do 2FA"],
      ["steamlib", "Se os jogos estiverem noutro disco (ex: D:), não vou formatar esse disco: depois basta adicionar a biblioteca na Steam"],
    ]},
    { group: "Ficheiros e licenças", items: [
      ["other", "Copiei ficheiros que estão fora das pastas habituais (ex: C:\\Projetos)"],
      ["keys", "Guardei as chaves de licença de programas pagos (Office, antivírus, jogos fora das lojas)"],
      ["github", "Guardei os códigos de recuperação do GitHub e de outros serviços com 2FA"],
    ]},
    { group: "Para formatar", items: [
      ["usb", "Tenho uma pen de instalação do Windows (Media Creation Tool da Microsoft)"],
      ["netdriver", "Guardei na pen o driver da placa de rede/Wi-Fi, para ter internet logo depois"],
      ["verify", "Abri a pasta Backup_… e confirmei que os meus saves estão lá"],
    ]},
  ],

  // Títulos de páginas do PCGamingWiki
  popular: [
    "Elden Ring", "Stardew Valley", "Terraria", "Hollow Knight", "The Witcher 3: Wild Hunt",
    "Baldur's Gate 3", "Cyberpunk 2077", "Red Dead Redemption 2", "Minecraft: Java Edition",
    "The Elder Scrolls V: Skyrim Special Edition", "Grand Theft Auto V", "Hades",
  ],
};
