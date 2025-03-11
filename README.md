# Instalação dos Módulos e Pré-Requisitos

## 1. Pré-Requisitos

- **PowerShell:** Por padrão o Powershell 5.x está instalado no Windows 10 e 11. Execute apenas nessa versão do Powershell, pois o mesmo não é compativel com o Powershell 7.x.
- **Privilégios de Administrador:** Execute o PowerShell com permissões elevadas para evitar problemas durante a instalação.
- **Conexão com a Internet:** Necessária para baixar os módulos da PowerShell Gallery.

## 2. Configurando a Política de Execução

Inicialmente, vamos ajustar a política de execução para permitir a execução de scripts na sessão atual sem alterar as configurações globais do sistema:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process
```

> **Observação:** Essa configuração é temporária e válida somente para a sessão atual. É uma prática recomendada para não comprometer a segurança do sistema permanentemente.

## 3. Instalação dos Módulos

Agora, vamos instalar os módulos necessários para gerenciar o Exchange Online, Microsoft Graph e AzureAD.

### 3.1. ExchangeOnlineManagement

Este módulo é essencial para gerenciar o Exchange Online.

```powershell
Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber
```

- **-Force:** Garante que a instalação seja efetuada mesmo se o módulo já existir.
- **-AllowClobber:** Permite que comandos conflitantes sejam sobrescritos, caso necessário.

### 3.2. Microsoft.Graph

Instala o módulo do Microsoft Graph, que possibilita o gerenciamento dos serviços do Microsoft 365.

```powershell
Install-Module Microsoft.Graph -Scope AllUsers
```

- **-Scope AllUsers:** Instala o módulo para todos os usuários do sistema.

### 3.3. AzureAD

Este módulo é utilizado para gerenciar o Azure Active Directory.

```powershell
Install-Module AzureAD -AllowClobber -Force
```

Após instalar os módulos, é recomendado ajustar a política de execução para um nível mais seguro:

```powershell
Set-ExecutionPolicy RemoteSigned -Force
```

> **Dica:** Esse comando garante que apenas scripts assinados sejam executados, aumentando a segurança da sua máquina.

## 4. Importando os Módulos

Depois de instalados, você precisa importar os módulos na sua sessão para poder utilizá-los. Confira como:

### 4.1. Importar ExchangeOnlineManagement

```powershell
Import-Module ExchangeOnlineManagement
```

### 4.2. Importar Microsoft.Graph

```powershell
Import-Module Microsoft.Graph
```

### 4.3. Importar AzureAD

```powershell
Import-Module AzureAD
```

Depois de importar, você já pode executar o script.
