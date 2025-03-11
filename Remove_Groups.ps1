#Requires -Modules ExchangeOnlineManagement, AzureAD

[CmdletBinding()]
param()

function Connect-RequiredServices {
    try {
        Write-Host "Conectando aos serviços necessários..." -ForegroundColor Cyan
        Connect-AzureAD -ErrorAction Stop
        Connect-ExchangeOnline -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "Erro ao conectar aos serviços: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-UserFromGroups {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Open.AzureAD.Model.User]$User
    )

    try {
        Write-Host "Processando usuário: $($User.UserPrincipalName)" -ForegroundColor Yellow

        # Verificar se o usuário está em pelo menos um grupo dinâmico
        $dynamicGroups = Get-AzureADUserMembership -ObjectId $User.ObjectId -ErrorAction SilentlyContinue | Where-Object {
            $_.ObjectType -eq "Group" -and
            $_.GroupTypes -contains "DynamicMembership"
        }
        if ($dynamicGroups) {
            Write-Host "Usuário vinculado a grupo(s) dinâmico(s). Removendo informação do campo Departamento..."
            Set-AzureADUser -ObjectId $User.ObjectId -Department $null -ErrorAction SilentlyContinue
            Write-Host "Campo Departamento removido com sucesso." -ForegroundColor Green
        }

        # Processar grupos do Azure AD (exceto dinâmicos, que já foram tratados acima)
        $aadGroups = Get-AzureADUserMembership -ObjectId $User.ObjectId -ErrorAction SilentlyContinue | Where-Object {
            $_.ObjectType -eq "Group" -and
            $_.DirSyncEnabled -ne $true -and
            -not ($_.GroupTypes -contains "DynamicMembership") -and
            -not $_.MailEnabled
        }
        foreach ($group in $aadGroups) {
            try {
                Remove-AzureADGroupMember -ObjectId $group.ObjectId -MemberId $User.ObjectId -ErrorAction SilentlyContinue
                Write-Host "Removido do grupo Azure AD: $($group.DisplayName)" -ForegroundColor Green
            }
            catch {}
        }

        # Processar grupos do Exchange Online com tratamento de erro silencioso
        $mailGroups = Get-UnifiedGroup -ResultSize Unlimited -ErrorAction SilentlyContinue
        $distributionGroups = Get-DistributionGroup -ResultSize Unlimited -ErrorAction SilentlyContinue
        $mailSecurityGroups = Get-Group -ResultSize Unlimited -ErrorAction SilentlyContinue | Where-Object {
            $_.GroupType -match "Universal" -and
            $_.GroupType -match "Security" -and
            -not ($_.IsDynamic)
        }

        # Remover de Microsoft 365 Groups
        foreach ($group in $mailGroups) {
            $owners = Get-UnifiedGroupLinks -Identity $group.Identity -LinkType Owners -ErrorAction SilentlyContinue
            if ($owners -and ($owners.PrimarySmtpAddress -contains $User.UserPrincipalName)) {
                try {
                    Remove-UnifiedGroupLinks -Identity $group.Identity -Links $User.UserPrincipalName -LinkType Owner -Confirm:$false -ErrorAction SilentlyContinue
                    Write-Host "Removido como proprietário do Microsoft 365 Group: $($group.DisplayName)" -ForegroundColor Green
                }
                catch {}
            }
            try {
                $members = Get-UnifiedGroupLinks -Identity $group.Identity -LinkType Members -ErrorAction SilentlyContinue
                if ($members | Where-Object { $_.PrimarySmtpAddress -eq $User.UserPrincipalName }) {
                    Remove-UnifiedGroupLinks -Identity $group.Identity -Links $User.UserPrincipalName -LinkType Member -Confirm:$false -ErrorAction SilentlyContinue
                    Write-Host "Removido do Microsoft 365 Group: $($group.DisplayName)" -ForegroundColor Green
                }
            }
            catch {}
        }

        # Remover de Distribution Groups
        foreach ($group in $distributionGroups) {
            try {
                $members = Get-DistributionGroupMember -Identity $group.Identity -ErrorAction SilentlyContinue
                if ($members | Where-Object { $_.PrimarySmtpAddress -eq $User.UserPrincipalName }) {
                    Remove-DistributionGroupMember -Identity $group.Identity -Member $User.UserPrincipalName -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction SilentlyContinue
                    Write-Host "Removido do Distribution Group: $($group.DisplayName)" -ForegroundColor Green
                }
            }
            catch {}
        }

        # Remover de Mail-Enabled Security Groups
        foreach ($group in $mailSecurityGroups) {
            try {
                $members = Get-DistributionGroupMember -Identity $group.Identity -ErrorAction SilentlyContinue
                if ($members | Where-Object { $_.PrimarySmtpAddress -eq $User.UserPrincipalName }) {
                    Remove-DistributionGroupMember -Identity $group.Identity -Member $User.UserPrincipalName -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction SilentlyContinue
                    Write-Host "Removido do Mail-Enabled Security Group: $($group.DisplayName)" -ForegroundColor Green
                }
            }
            catch {}
        }
    }
    catch {
        Write-Host "Erro durante o processamento do usuário $($User.UserPrincipalName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

try {
    if (Connect-RequiredServices) {
        $desligadosUsers = Get-AzureADUser -All $true | Where-Object { $_.DisplayName -like "*DESLIGADO*" }
        
        if ($desligadosUsers.Count -eq 0) {
            Write-Host "Nenhum usuário encontrado com 'DESLIGADO' no nome." -ForegroundColor Yellow
        }
        else {
            Write-Host "Encontrados $($desligadosUsers.Count) usuários com 'DESLIGADO' no nome." -ForegroundColor Cyan
            foreach ($user in $desligadosUsers) {
                Remove-UserFromGroups -User $user
            }
        }
    }
}
finally {
    if (Get-PSSession | Where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" }) {
        Disconnect-ExchangeOnline -Confirm:$false
    }
    if (Get-AzureADCurrentSessionInfo -ErrorAction SilentlyContinue) {
        Disconnect-AzureAD
    }
    Write-Host "Processo concluído." -ForegroundColor Cyan
}
