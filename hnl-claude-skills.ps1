# agent-skills
if (-not $env:AGENT_SKILLS) {
    if ($env:CLAUDE_SKILLS) {
        $env:AGENT_SKILLS = $env:CLAUDE_SKILLS
    } else {
        $env:AGENT_SKILLS = $PSScriptRoot
    }
}
if (-not $env:CLAUDE_SKILLS) {
    $env:CLAUDE_SKILLS = $env:AGENT_SKILLS
}
if (-not $env:AGENT_SKILLS_TARGETS) {
    $env:AGENT_SKILLS_TARGETS = ".claude\skills;.codex\skills"
}

function _skill-target-dirs {
    $env:AGENT_SKILLS_TARGETS -split ';' | Where-Object { $_ }
}

function _skill-canonical-path {
    param($path)
    if (-not $path) { return $null }
    try {
        $fullPath = [System.IO.Path]::GetFullPath([string]$path)
        if (Test-Path -LiteralPath $fullPath) {
            $fullPath = (Resolve-Path -LiteralPath $fullPath -ErrorAction Stop).ProviderPath
        }
        return $fullPath.TrimEnd([char[]]"\/")
    } catch {
        return $null
    }
}

function _skill-managed-target {
    param($target)
    $targetText = _skill-canonical-path $target
    if (-not $targetText) { return $false }
    foreach ($root in @($env:AGENT_SKILLS, $env:CLAUDE_SKILLS)) {
        $rootText = _skill-canonical-path $root
        if (-not $rootText) { continue }
        if ($targetText -eq $rootText) { return $true }
        if ($targetText.StartsWith("$rootText\", [StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ($targetText.StartsWith("$rootText/", [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function _skill-target-label {
    param([string]$target)
    if ($target -match '(^|[\\/])\.claude[\\/]skills$') { return "claude" }
    if ($target -match '(^|[\\/])\.codex[\\/]skills$') { return "codex" }
    return $target
}

function skill-ls {
    $targetDirs = @(_skill-target-dirs)
    Get-ChildItem $env:AGENT_SKILLS -Directory | Where-Object { $_.Name -notlike '.*' } | ForEach-Object {
        $name = $_.Name
        $installedLabels = @()
        $missingLabels = @()
        foreach ($skillsDir in $targetDirs) {
            if (Test-Path (Join-Path $skillsDir $name)) {
                $installedLabels += (_skill-target-label $skillsDir)
            } else {
                $missingLabels += (_skill-target-label $skillsDir)
            }
        }
        if ($installedLabels.Count -eq $targetDirs.Count -and $installedLabels.Count -gt 0) {
            Write-Host "$name [installed: $($installedLabels -join ',')]" -ForegroundColor Green
        } elseif ($installedLabels.Count -gt 0) {
            Write-Host "$name [partial: $($installedLabels -join ','); missing: $($missingLabels -join ',')]" -ForegroundColor Yellow
        } else {
            Write-Host $name
        }
    }
}

function skill-add {
    foreach ($skillsDir in (_skill-target-dirs)) {
        New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
    }
    foreach ($s in $args) {
        $src = "$env:AGENT_SKILLS\$s"
        if (-not (Test-Path $src)) {
            Write-Host "NOT_FOUND: $s"
            continue
        }
        foreach ($skillsDir in (_skill-target-dirs)) {
            $dst = Join-Path $skillsDir $s
            if (Test-Path $dst) {
			    $item = Get-Item $dst
			    $isManagedJunction = ($item.LinkType -eq "Junction") -and (_skill-managed-target $item.Target)
			    if ($isManagedJunction) {
				    Write-Host "ALREADY_INSTALLED: $s ($skillsDir)"
				    continue
			    } else {
				    Write-Host "EXISTS: $s ($skillsDir; not managed by agent-skills, skipping)"
				    continue
			    }
		    }
		    New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
		    Write-Host "OK: $s ($skillsDir)"
        }
    }
}

function skill-add-all {
    Get-ChildItem $env:AGENT_SKILLS -Directory | ForEach-Object {
        skill-add $_.Name
    }
}

function skill-remove {
    foreach ($s in $args) {
        foreach ($skillsDir in (_skill-target-dirs)) {
            $dst = Join-Path $skillsDir $s
            if (Test-Path $dst) {
                $item = Get-Item $dst
                $isManagedJunction = ($item.LinkType -eq "Junction") -and (_skill-managed-target $item.Target)
                if ($isManagedJunction) {
                    cmd /c rmdir "$dst"
                    Write-Host "REMOVED: $s ($skillsDir)"
                } else {
                    Write-Host "EXTERNAL: $s ($skillsDir; not managed by agent-skills, skipping)"
                }
            } else {
                Write-Host "NOT FOUND: $s ($skillsDir)"
            }
        }
    }
}

function _load-bundles {
    $bundleFile = "$env:AGENT_SKILLS\bundles.conf"
    if (-not (Test-Path $bundleFile)) {
        Write-Host "ERROR: bundles.conf not found in $env:AGENT_SKILLS"
        exit 1
    }
    $bundles = @{}
    $current = $null
    foreach ($line in Get-Content $bundleFile) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        if ($line -match '^\[(.+)\]$') {
            $current = $Matches[1]
            $bundles[$current] = [PSCustomObject]@{ skills = @(); extends = @() }
            continue
        }
        if ($null -eq $current) { continue }
        if ($line -match '^extends=(.+)$') {
            $bundles[$current].extends = $Matches[1] -split ',' | ForEach-Object { $_.Trim() }
            continue
        }
        $bundles[$current].skills += $line
    }
    return $bundles
}

function _resolve-bundle {
    param(
        [string]$name,
        [hashtable]$bundles,
        [System.Collections.Generic.List[string]]$resolved,
        [System.Collections.Generic.List[string]]$visiting
    )
    if ($visiting.Contains($name)) {
        Write-Host "ERROR: Circular extends detected at bundle '$name'"
        exit 1
    }
    if (-not $bundles.ContainsKey($name)) {
        Write-Host "ERROR: Bundle '$name' not found"
        exit 1
    }
    $visiting.Add($name) | Out-Null
    $bundle = $bundles[$name]
    if ($bundle.extends) {
        foreach ($parent in $bundle.extends) {
            _resolve-bundle -name $parent -bundles $bundles -resolved $resolved -visiting $visiting
        }
    }
    foreach ($skill in $bundle.skills) {
        if (-not $resolved.Contains($skill)) {
            $resolved.Add($skill) | Out-Null
        }
    }
    $visiting.Remove($name) | Out-Null
}

function skill-ls-bundles {
    param([string]$filter = "")
    $bundles = _load-bundles
    $names = if ($filter) {
        if (-not $bundles.ContainsKey($filter)) {
            Write-Host "ERROR: Bundle '$filter' not found"
            return
        }
        @($filter)
    } else {
        $bundles.Keys
    }
    foreach ($name in $names) {
        $resolved = [System.Collections.Generic.List[string]]::new()
        $visiting = [System.Collections.Generic.List[string]]::new()
        _resolve-bundle -name $name -bundles $bundles -resolved $resolved -visiting $visiting
        Write-Host ""
        Write-Host "[$name]"
        foreach ($skill in $resolved) { Write-Host "  $skill" }
    }
}

function skill-bundle-add {
    param([string]$bundle = "")
    if (-not $bundle) {
        Write-Host "Usage: skill-bundle-add <bundle>"
        Write-Host "Run 'skill-ls-bundles' to see available bundles"
        return
    }
    $bundles = _load-bundles
    $resolved = [System.Collections.Generic.List[string]]::new()
    $visiting = [System.Collections.Generic.List[string]]::new()
    _resolve-bundle -name $bundle -bundles $bundles -resolved $resolved -visiting $visiting
    Write-Host "Installing bundle '$bundle' ($($resolved.Count) skills):"
    foreach ($skill in $resolved) { skill-add $skill }
}

function skill-bundle-remove {
    param([string]$bundle = "")
    if (-not $bundle) {
        Write-Host "Usage: skill-bundle-remove <bundle>"
        Write-Host "Run 'skill-ls-bundles' to see available bundles"
        return
    }
    $bundles = _load-bundles
    $resolved = [System.Collections.Generic.List[string]]::new()
    $visiting = [System.Collections.Generic.List[string]]::new()
    _resolve-bundle -name $bundle -bundles $bundles -resolved $resolved -visiting $visiting
    Write-Host "Removing bundle '$bundle' ($($resolved.Count) skills):"
    foreach ($skill in $resolved) { skill-remove $skill }
}


function skill-ls-installed {
    $count = 0
    foreach ($skillsDir in (_skill-target-dirs)) {
        if (-not (Test-Path $skillsDir)) { continue }
        Write-Host "[$skillsDir]"
        foreach ($item in (Get-ChildItem $skillsDir)) {
            $count++
            $isJunction = $item.Attributes -band [IO.FileAttributes]::ReparsePoint
            if ($isJunction) {
                $target = (Get-Item $item.FullName).Target
                if (_skill-managed-target $target) {
                    Write-Host "LINKED:   $($item.Name) -> $target"
                } else {
                    Write-Host "EXTERNAL: $($item.Name) -> $target"
                }
            } else {
                Write-Host "EXTERNAL: $($item.Name) (local directory)"
            }
        }
    }
    if ($count -eq 0) {
        Write-Host "No skills installed in current project."
    }
}

function skill-update {
    Write-Host "Updating agent-skills..."
    Push-Location $env:AGENT_SKILLS
    git pull
    git submodule update --remote
    Pop-Location
}
