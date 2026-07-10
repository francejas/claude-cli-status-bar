[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- Emojis / glyphs via code points (safe under any script encoding) ----
$E_LEAF  = [char]::ConvertFromUtf32(0x1F33F)  # leaf
$E_BOT   = [char]::ConvertFromUtf32(0x1F916)  # robot
$E_GREEN = [char]::ConvertFromUtf32(0x1F7E2)  # green circle
$E_BOLT  = [char]::ConvertFromUtf32(0x26A1)   # high voltage
$E_FIRE  = [char]::ConvertFromUtf32(0x1F525)  # fire
$E_SIREN = [char]::ConvertFromUtf32(0x1F6A8)  # siren
$E_RESET = [char]::ConvertFromUtf32(0x21BB)   # clockwise arrow
$BLOCK   = [char]0x2588                        # full block
$ESC     = [char]27

# ---- ANSI helpers ----
function RGB([int]$r,[int]$g,[int]$b,[string]$s) { "$ESC[38;2;$r;$g;${b}m$s$ESC[0m" }
function Bold([string]$s) { "$ESC[1m$s$ESC[0m" }
$PIPE = RGB 90 90 90 " | "   # dim gray separator

# ---- usage -> emoji ----
function UsageEmoji([double]$p) {
    if ($p -ge 90) { return $E_SIREN }
    elseif ($p -ge 70) { return $E_FIRE }
    elseif ($p -ge 20) { return $E_BOLT }
    else { return $E_GREEN }
}

# ---- usage -> percentage color ----
function PctColored([double]$p) {
    $txt = ("{0:N0}%" -f $p)
    if ($p -ge 90)      { return (RGB 220 40 20 $txt) }
    elseif ($p -ge 70)  { return (RGB 235 140 0 $txt) }
    elseif ($p -ge 20)  { return (RGB 220 200 0 $txt) }
    else                { return (RGB 0 200 80 $txt) }
}

# ---- gradient color at position t in [0,1]: green -> yellow -> red ----
function GradColor([double]$t) {
    if ($t -lt 0) { $t = 0 }; if ($t -gt 1) { $t = 1 }
    if ($t -le 0.5) {
        $u = $t / 0.5
        $r = [int](0   + (220 - 0)   * $u)
        $g = [int](200 + (200 - 200) * $u)
        $b = [int](80  + (0   - 80)  * $u)
    } else {
        $u = ($t - 0.5) / 0.5
        $r = [int](220 + (220 - 220) * $u)
        $g = [int](200 + (40  - 200) * $u)
        $b = [int](0   + (20  - 0)   * $u)
    }
    return @($r,$g,$b)
}

# ---- RGB gradient bar ----
function Bar([double]$p) {
    $n = 12
    $filled = [int][math]::Round(($p / 100.0) * $n)
    if ($filled -lt 0) { $filled = 0 }; if ($filled -gt $n) { $filled = $n }
    $sb = ""
    for ($i = 0; $i -lt $n; $i++) {
        if ($i -lt $filled) {
            $t = if ($n -gt 1) { $i / ($n - 1) } else { 0 }
            $c = GradColor $t
            $sb += (RGB $c[0] $c[1] $c[2] $BLOCK)
        } else {
            $sb += (RGB 60 60 60 $BLOCK)
        }
    }
    return $sb
}

# ---- time until reset ----
function TimeToReset([long]$resetsAt) {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $rem = $resetsAt - $now
    if ($rem -le 0) { return "now" }
    $d = [math]::Floor($rem / 86400); $rem -= $d * 86400
    $h = [math]::Floor($rem / 3600);  $rem -= $h * 3600
    $m = [math]::Floor($rem / 60)
    if ($d -gt 0)      { return ("{0}d{1}h" -f $d, $h) }
    elseif ($h -gt 0)  { return ("{0}h{1}m" -f $h, $m) }
    else               { return ("{0}m" -f $m) }
}

# ---- one rate-limit window segment ----
function RateSeg([string]$label, $win) {
    if ($null -eq $win -or $null -eq $win.used_percentage) { return $null }
    $p = [double]$win.used_percentage
    $seg = (RGB 90 90 90 $label) + " " + (UsageEmoji $p) + " " + (Bar $p) + " " + (PctColored $p)
    if ($null -ne $win.resets_at) {
        $seg += " " + (RGB 120 120 120 ("{0} {1}" -f $E_RESET, (TimeToReset ([long]$win.resets_at))))
    }
    return $seg
}

# ---- git dirty count: +staged ~modified ----
function GitDirty([string]$dir) {
    try {
        $staged = (git -C "$dir" diff --cached --numstat 2>$null | Measure-Object -Line).Lines
        $modified = (git -C "$dir" diff --numstat 2>$null | Measure-Object -Line).Lines
        $untracked = (git -C "$dir" ls-files --others --exclude-standard 2>$null | Measure-Object -Line).Lines
        $seg = ""
        if ($staged -gt 0)    { $seg += (RGB 0 200 80 "+$staged") }
        if ($modified -gt 0)  { $seg += " " + (RGB 220 200 0 "~$modified") }
        if ($untracked -gt 0) { $seg += " " + (RGB 150 150 150 "?$untracked") }
        return $seg.Trim()
    } catch { return "" }
}

# ---- CAVEMAN badge from plugin flag file (dynamic, whitelist-validated) ----
function CavemanBadge {
    try {
        $claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
        $flag = Join-Path $claudeDir ".caveman-active"
        if (-not (Test-Path -LiteralPath $flag)) { return "" }
        $item = Get-Item -LiteralPath $flag -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -or $item.Length -gt 64) { return "" }
        $mode = ((Get-Content -LiteralPath $flag -TotalCount 1 -ErrorAction Stop) | Out-String).Trim().ToLowerInvariant()
        $mode = ($mode -replace '[^a-z0-9-]', '')
        $valid = @('off','lite','full','ultra','wenyan-lite','wenyan','wenyan-full','wenyan-ultra','commit','review','compress')
        if (-not ($valid -contains $mode)) { return "" }
        $label = if ($mode -eq "full") { "[CAVEMAN]" } else { "[CAVEMAN:$($mode.ToUpperInvariant())]" }
        return (RGB 200 130 40 $label)
    } catch { return "" }
}

# ---- read stdin ----
$raw = [Console]::In.ReadToEnd()
try { $in = $raw | ConvertFrom-Json } catch { exit 0 }

$parts = @()

# 1) Repo / folder name — bold yellow
$dir = $null
try {
    $dir = $in.workspace.current_dir
    if ([string]::IsNullOrEmpty($dir)) { $dir = $in.cwd }
    if (-not [string]::IsNullOrEmpty($dir)) {
        $parts += (Bold (RGB 220 200 0 (Split-Path -Leaf $dir)))
    }
} catch {}

# 2) Git branch — leaf icon + bold cyan in parentheses (only if inside a repo)
try {
    if (-not [string]::IsNullOrEmpty($dir)) {
        $branch = (git -C "$dir" rev-parse --abbrev-ref HEAD 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($branch)) {
            $seg = "$E_LEAF " + (Bold (RGB 0 200 200 ("($branch)")))
            $dirty = GitDirty $dir
            if ($dirty -ne "") { $seg += " " + $dirty }
            $parts += $seg
        }
    }
} catch {}

# 3) Model — robot icon + magenta (effort in parens), with CAVEMAN badge
try {
    $model = $in.model.display_name
    if (-not [string]::IsNullOrEmpty($model)) {
        # strip trailing parenthetical (e.g. " (1M context)")
        $model = ($model -replace '\s*\(.*\)\s*$', '').Trim()

        # effort: prefer stdin, else read effortLevel from settings.json
        $effort = $null
        if ($in.PSObject.Properties.Match('effort').Count -and $in.effort) { $effort = [string]$in.effort }
        elseif ($in.model.PSObject.Properties.Match('effort').Count -and $in.model.effort) { $effort = [string]$in.model.effort }
        else {
            try {
                $claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
                $cfg = Join-Path $claudeDir "settings.json"
                if (Test-Path -LiteralPath $cfg) {
                    $s = (Get-Content -LiteralPath $cfg -Raw -ErrorAction Stop | ConvertFrom-Json)
                    $el = $s.effortLevel
                    if ($el -is [string]) { $effort = $el }
                    elseif ($null -ne $el -and $el.level) { $effort = [string]$el.level }
                }
            } catch {}
        }

        # normalize accidental object-ish string like "@{level=medium}"
        if ($effort -match 'level=([a-z]+)') { $effort = $Matches[1] }

        $seg = "$E_BOT " + (RGB 210 60 210 $model)
        if (-not [string]::IsNullOrEmpty($effort)) {
            $seg += " " + (RGB 130 130 130 "($effort)")
        }
        $badge = CavemanBadge
        if ($badge -ne "") { $seg += " " + $badge }
        $parts += $seg
    }
} catch {}

# 4) Rate limit (5h)
try {
    $rl = $in.rate_limits
    if ($null -ne $rl) {
        $s5 = RateSeg "5h" $rl.five_hour
        if ($s5) { $parts += $s5 }
    }
} catch {}

# 5) Context window usage — colored % only (no bar)
try {
    $cw = $in.context_window
    if ($null -ne $cw -and $null -ne $cw.used_percentage) {
        $p = [double]$cw.used_percentage
        $parts += ((RGB 90 90 90 "ctx") + " " + (PctColored $p))
    }
} catch {}

# 6) Cost | lines added/removed
try {
    $cost = $in.cost
    if ($null -ne $cost) {
        $costSeg = $null
        if ($null -ne $cost.total_cost_usd) {
            $inv = [System.Globalization.CultureInfo]::InvariantCulture
            $costVal = [double]$cost.total_cost_usd
            $costSeg = (RGB 255 215 0 ('$' + $costVal.ToString("N2", $inv)))
        }
        $linesSeg = $null
        if ($null -ne $cost.total_lines_added -or $null -ne $cost.total_lines_removed) {
            $added = if ($cost.total_lines_added) { [int]$cost.total_lines_added } else { 0 }
            $removed = if ($cost.total_lines_removed) { [int]$cost.total_lines_removed } else { 0 }
            if ($added -gt 0 -or $removed -gt 0) {
                $linesSeg = (RGB 0 200 80 "+$added") + " " + (RGB 220 40 20 "-$removed")
            }
        }
        if ($null -ne $costSeg -and $null -ne $linesSeg) { $parts += ($costSeg + $PIPE + $linesSeg) }
        elseif ($null -ne $costSeg) { $parts += $costSeg }
        elseif ($null -ne $linesSeg) { $parts += $linesSeg }
    }
} catch {}

[Console]::Write($parts -join $PIPE)
