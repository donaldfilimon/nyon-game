# Deployment Tracker - Phase 1, 2, 3 Enhancement Status
# Tracks implementation progress for performance optimizations

param(
    [switch]$Check,
    [switch]$Status,
    [switch]$Phase1,
    [switch]$Phase2,
    [switch]$Phase3,
    [switch]$All
)

$ErrorActionPreference = "Continue"

# Color output functions
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success { Write-ColorOutput Green $args }
function Write-Warning { Write-ColorOutput Yellow $args }
function Write-Error { Write-ColorOutput Red $args }
function Write-Info { Write-ColorOutput Cyan $args }

# Phase 1 - Near Term
$Phase1Items = @(
    @{
        Name = "MemoryPool for entity IDs"
        Description = "High-churn allocation optimization for entity ID management"
        File = "src/ecs/entity.zig"
        Pattern = "MemoryPool|ObjectPool|entity.*pool|pool.*entity"
        Status = $false
    },
    @{
        Name = "ArrayHashMap for archetype queries"
        Description = "Stable iteration for archetype lookups"
        File = "src/ecs/world.zig"
        Pattern = "ArrayHashMap|std\.hash_map\.ArrayHashMap"
        Status = $false
    },
    @{
        Name = "Profiling integration"
        Description = "Measure actual performance gains"
        File = "src/performance.zig"
        Pattern = "profiling|Profiler|measureGains|performance.*measure|benchmark"
        Status = $false
    }
)

# Phase 2 - Medium Term
$Phase2Items = @(
    @{
        Name = "Parallel ECS query execution"
        Description = "Job system for parallel query processing"
        File = "src/ecs"
        Pattern = "parallel|job.*system|thread.*pool"
        Status = $false
    },
    @{
        Name = "GPU-driven rendering"
        Description = "Compute shaders for rendering pipeline"
        File = "src/rendering"
        Pattern = "compute.*shader|gpu.*driven"
        Status = $false
    },
    @{
        Name = "Texture streaming for large worlds"
        Description = "Stream textures based on distance/visibility"
        File = "src/rendering"
        Pattern = "texture.*stream|streaming"
        Status = $false
    }
)

# Phase 3 - Long Term
$Phase3Items = @(
    @{
        Name = "Custom allocators for specific subsystems"
        Description = "Specialized allocators per subsystem"
        File = "src/common/memory.zig"
        Pattern = "custom.*allocator|subsystem.*allocator"
        Status = $false
    },
    @{
        Name = "Hot-reloading of compiled shaders"
        Description = "Reload shaders without restart"
        File = "src/rendering"
        Pattern = "hot.*reload|shader.*reload"
        Status = $false
    },
    @{
        Name = "Memory tracking and profiling tools"
        Description = "Tools for memory usage analysis"
        File = "src/performance.zig"
        Pattern = "memory.*track|profiling.*tool"
        Status = $false
    }
)

function Check-Implementation {
    param($Item)
    
    $filePath = $Item.File
    if (-not (Test-Path $filePath)) {
        # Try to find in directory
        if (Test-Path $filePath -PathType Container) {
            $files = Get-ChildItem -Path $filePath -Recurse -Filter "*.zig" -ErrorAction SilentlyContinue
            $found = $false
            foreach ($file in $files) {
                $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -match $Item.Pattern) {
                    $found = $true
                    break
                }
            }
            return $found
        }
        return $false
    }
    
    $content = Get-Content $filePath -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -match $Item.Pattern) {
        return $true
    }
    return $false
}

function Show-PhaseStatus {
    param($PhaseName, $Items, $PhaseNumber)
    
    Write-Info "`n=== $PhaseName ===" 
    Write-Info "Phase $PhaseNumber - $(if ($PhaseNumber -eq 1) { 'Near Term' } elseif ($PhaseNumber -eq 2) { 'Medium Term' } else { 'Long Term' })"
    Write-Info ""
    
    $completed = 0
    foreach ($item in $Items) {
        $status = Check-Implementation $item
        $item.Status = $status
        
        $statusIcon = if ($status) { "[✓]" } else { "[ ]" }
        $statusText = if ($status) { "IMPLEMENTED" } else { "PENDING" }
        $statusColor = if ($status) { "Green" } else { "Yellow" }
        
        Write-ColorOutput $statusColor "$statusIcon $($item.Name)"
        Write-Output "    $($item.Description)"
        Write-Output "    File: $($item.File)"
        Write-Output "    Status: $statusText"
        Write-Output ""
        
        if ($status) { $completed++ }
    }
    
    $total = $Items.Count
    $percentage = [math]::Round(($completed / $total) * 100, 1)
    Write-Info "Progress: $completed/$total ($percentage%)"
    
    return @{
        Completed = $completed
        Total = $total
        Percentage = $percentage
    }
}

function Show-FullStatus {
    Write-Info "`n========================================"
    Write-Info "  DEPLOYMENT ENHANCEMENT STATUS"
    Write-Info "========================================`n"
    
    $phase1Stats = Show-PhaseStatus "Phase 1 - Near Term" $Phase1Items 1
    Write-Output ""
    $phase2Stats = Show-PhaseStatus "Phase 2 - Medium Term" $Phase2Items 2
    Write-Output ""
    $phase3Stats = Show-PhaseStatus "Phase 3 - Long Term" $Phase3Items 3
    
    Write-Info "`n========================================"
    Write-Info "  OVERALL PROGRESS"
    Write-Info "========================================`n"
    
    $totalCompleted = $phase1Stats.Completed + $phase2Stats.Completed + $phase3Stats.Completed
    $totalItems = $phase1Stats.Total + $phase2Stats.Total + $phase3Stats.Total
    $overallPercentage = [math]::Round(($totalCompleted / $totalItems) * 100, 1)
    
    Write-Info "Total: $totalCompleted/$totalItems ($overallPercentage%)"
    Write-Info "Phase 1: $($phase1Stats.Completed)/$($phase1Stats.Total) ($($phase1Stats.Percentage)%)"
    Write-Info "Phase 2: $($phase2Stats.Completed)/$($phase2Stats.Total) ($($phase2Stats.Percentage)%)"
    Write-Info "Phase 3: $($phase3Stats.Completed)/$($phase3Stats.Total) ($($phase3Stats.Percentage)%)"
}

function Check-BuildStatus {
    Write-Info "`nChecking build status...`n"
    
    $buildSuccess = $false
    $testSuccess = $false
    
    # Check if zig is available
    try {
        $zigVersion = zig version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Zig compiler found"
            Write-Output "  $zigVersion"
        } else {
            Write-Warning "⚠ Zig compiler not found or error"
        }
    } catch {
        Write-Warning "⚠ Zig compiler not found in PATH"
    }
    
    # Try to build
    Write-Info "`nAttempting build check..."
    try {
        $buildOutput = zig build 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Build successful"
            $buildSuccess = $true
        } else {
            Write-Warning "⚠ Build failed (this may be due to dependency issues)"
            Write-Output $buildOutput
        }
    } catch {
        Write-Warning "⚠ Could not run build check"
    }
    
    # Try to run tests
    Write-Info "`nAttempting test check..."
    try {
        $testOutput = zig build test 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Tests passed"
            $testSuccess = $true
        } else {
            Write-Warning "⚠ Tests failed"
            Write-Output $testOutput
        }
    } catch {
        Write-Warning "⚠ Could not run tests"
    }
    
    return @{
        BuildSuccess = $buildSuccess
        TestSuccess = $testSuccess
    }
}

# Main execution
if ($Status) {
    Show-FullStatus
    Check-BuildStatus
    exit
}

if ($Check) {
    $buildStatus = Check-BuildStatus
    Write-Info "`nBuild Status: $(if ($buildStatus.BuildSuccess) { 'SUCCESS' } else { 'FAILED/UNKNOWN' })"
    Write-Info "Test Status: $(if ($buildStatus.TestSuccess) { 'PASSED' } else { 'FAILED/UNKNOWN' })"
    exit
}

if ($Phase1) {
    Show-PhaseStatus "Phase 1 - Near Term" $Phase1Items 1
    exit
}

if ($Phase2) {
    Show-PhaseStatus "Phase 2 - Medium Term" $Phase2Items 2
    exit
}

if ($Phase3) {
    Show-PhaseStatus "Phase 3 - Long Term" $Phase3Items 3
    exit
}

# Default: show all
if ($All -or (-not $Phase1 -and -not $Phase2 -and -not $Phase3 -and -not $Check -and -not $Status)) {
    Show-FullStatus
}

Write-Info "`nUse -Help for usage information"
Write-Info "Examples:"
Write-Info "  .\deployment_tracker.ps1              # Show all status"
Write-Info "  .\deployment_tracker.ps1 -Phase1      # Show Phase 1 only"
Write-Info "  .\deployment_tracker.ps1 -Check       # Check build/test status"
Write-Info "  .\deployment_tracker.ps1 -Status       # Full status + build check"
