# Formatar Sem Medo 💾

**Vais formatar o PC? Não percas nada.**

🔗 **https://gui198gui.github.io/formatar-sem-medo/**

Toda a gente adia a formatação do PC pelo mesmo motivo: o medo de perder saves e definições, e a preguiça
de voltar a instalar tudo. Esta app gera um **kit de backup personalizado** que trata disso:

1. **Escolhes os teus jogos.** A localização dos saves e das definições de cada um vem da API do
   [PCGamingWiki](https://www.pcgamingwiki.com), com milhares de jogos.
2. **Escolhes os programas, as pastas e as opções de sistema:** definições do VS Code, Windows Terminal,
   OBS, Git, chaves SSH, pastas pessoais, redes Wi-Fi, drivers…
3. **Confirmas a checklist de contas**, para o que não se pode copiar (palavras-passe do browser, 2FA,
   BitLocker, licença do Windows…).
4. **Descarregas um ZIP** com:
   - `FAZER-BACKUP.bat`: copia tudo para uma pasta `Backup_…` na pen ou disco externo
   - `RESTAURAR.bat`: depois de formatar, repõe os ficheiros no sítio certo e **reinstala os programas de
     uma vez** com o `winget`
   - `CHECKLIST.txt` e `LEIA-ME.txt`

## Como funciona

### App web (sem servidor)
- HTML, CSS e JavaScript, sem frameworks; está alojada no GitHub Pages
- Pesquisa e dados dos jogos através da **MediaWiki API** do PCGamingWiki (`opensearch` + `parse`), que permite pedidos de qualquer site (CORS)
- **Parser de wikitext** para os templates `{{Game data/saves}}` e `{{Game data/config}}`: lida com templates
  aninhados, notas `<ref>` e várias plataformas (Windows, Steam, GOG, Epic…), e converte as variáveis do wiki
  (`{{p|appdata}}`, `{{p|uid}}`, `{{p|game}}`…) em variáveis portáteis
- As escolhas ficam guardadas no browser (`localStorage`); o ZIP é gerado no browser com JSZip

### Scripts PowerShell (`scripts/`)
- **Só copiam** ficheiros (`robocopy` sem `/MIR` nem `/PURGE`) e exportam chaves do registo (`reg export`); nunca apagam nada
- Resolvem as pastas reais em cada PC: Documentos (mesmo que estejam no OneDrive), `%APPDATA%`, `LocalLow`,
  a pasta da Steam (pelo registo) e **todas as bibliotecas Steam** (`libraryfolders.vdf`). Encontram a pasta de instalação
  de cada jogo pelo `appmanifest_<appid>.acf`
- Guardam cada caminho como **raiz + caminho relativo** num `manifest.json`. Assim o restauro funciona mesmo
  com outro nome de utilizador ou com a Steam noutro disco
- Também usam `winget export`/`import`, `netsh wlan export profile`, `pnputil /export-driver` e a lista de programas instalados lida do registo
- O restauro pode ser corrido várias vezes: o que depende de um jogo ainda não instalado fica pendente
  até voltares a correr o script

### Testes
- Parser testado com os dados reais do PCGamingWiki para 13 jogos populares
- Backup e restauro testados de ponta a ponta com PowerShell 7 num "PC simulado", incluindo restauro para outro
  utilizador e com a biblioteca Steam noutro disco

## Limitações

- As palavras-passe guardadas nos browsers são cifradas pelo Windows e **não podem** ser copiadas por script.
  Usa a sincronização do browser ou exporta-as para um gestor de palavras-passe (está na checklist)
- Jogos cujos saves estão na pasta de instalação só são encontrados automaticamente se forem da Steam
- Depende dos dados do PCGamingWiki: se o wiki não tiver a localização dos saves de um jogo, a app avisa

## Correr localmente

```bash
python -m http.server 8000
# abrir http://localhost:8000
```

## Licença

Código sob licença MIT. Os dados dos jogos vêm do PCGamingWiki (CC BY-NC-SA 3.0).

## Autor

**Guilherme Martins**, estudante de Engenharia Informática no IPCB.
[Portefólio](https://gui198gui.github.io) · [LinkedIn](https://www.linkedin.com/in/guilherme-martins-158279309/) · [GitHub](https://github.com/gui198gui)
