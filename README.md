# LinkRouter

[![Version](https://img.shields.io/badge/version-1.0.0-red.svg)](https://github.com/arbgjr/linkrouter)
[![License](https://img.shields.io/badge/license-MIT-red.svg)](LICENSE)
[![AutoHotKey](https://img.shields.io/badge/AutoHotkey-v2.0-darkgreen.svg)](https://www.autohotkey.com/)

<a href="https://www.autohotkey.com/"><img src="https://i.imgur.com/tjPOPhB.png" alt="AutoHotkey Logo" width="48" /></a>

LinkRouter é um roteador de links para Windows que permite direcionar URLs para diferentes navegadores com base no aplicativo de origem. Ideal para quem usa múltiplos browsers e deseja regras personalizadas para abertura de links.

## Funcionalidades

- Intercepta links HTTP/HTTPS no Windows
- Roteia para browsers diferentes conforme o processo de origem (ex: Teams → Chrome, Explorer → Edge)
- Configuração via arquivo JSON
- Log detalhado de decisões e erros
- Instalação e atualização automatizadas via PowerShell

## Instalação

1. **Pré-requisitos:**

- Windows 10/11
- [AutoHotkey v2.0](https://www.autohotkey.com/download/)
- **Ahk2Exe** (vem junto com o instalador do AutoHotkey, mas pode ser baixado separadamente em: <https://www.autohotkey.com/download/ahk2exe.zip>)

  **Instalação do AutoHotkey v2:**

- Baixe e execute o instalador do site oficial.
- Certifique-se de instalar a versão 2.x (não a 1.x).

  **Instalação do Ahk2Exe:**

- O compilador geralmente está em `C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe` após instalar o AutoHotkey.
- Se não estiver, extraia o zip do Ahk2Exe e coloque na mesma pasta do AutoHotkey.

1. **Build e deploy:**

- Execute o script PowerShell:

    ```powershell
    .\build-linkrouter.ps1
    ```

- O script compila, instala e registra o LinkRouter como handler de URL.
- O Explorer será reiniciado automaticamente para aplicar as associações.

1. **Configuração:**

- Edite o arquivo `linkrouter.config.json` na pasta de instalação.
- Exemplo:

     ```json
     {
       "default": "edge",
       "logPath": ".\\logs\\linkrouter.log",
       "browsers": { "edge": "C:\\...\\msedge.exe", "chrome": "C:\\...\\chrome.exe" },
       "rules": { "ms-teams.exe": "chrome" }
     }
     ```

## Uso

- Após instalado, qualquer link aberto no Windows será roteado conforme as regras.
- Logs podem ser consultados em `%TEMP%\linkrouter_debug.log` ou no caminho definido em `logPath`.
- Para testar: `Start-Process "https://example.com"` no PowerShell.

## Contribuindo

1. Fork o repositório e crie uma branch para sua feature/fix.
2. Siga o padrão dos scripts e mantenha a compatibilidade com AHK v2.
3. Faça PRs claros e com descrição do problema/solução.
4. Testes são manuais, verifique logs e cenários de erro.

## Estrutura do Projeto

- `LinkRouter.ahk`: Script principal (AutoHotkey v2)
- `linkrouter.config.json`: Configuração de regras
- `build-linkrouter.ps1`: Build, deploy e registro

## Suporte e Dúvidas

Abra uma issue ou discuta no PR. Sugestões e melhorias são bem-vindas!

---

**Atenção:**

- O script reinicia o Explorer durante a instalação.
- Mudanças na configuração exigem reinício do LinkRouter.
- Compatível apenas com AutoHotkey v2.
