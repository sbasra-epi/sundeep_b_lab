$folder = "D:\sunde\OneDrive\Documents\Finances\American Express\TrueEarnings Business Card\AMEX 2011 Statements"

$monthMap = @{
    Jan = "01"; Feb = "02"; Mar = "03"; Apr = "04";
    May = "05"; Jun = "06"; Jul = "07"; Aug = "08";
    Sep = "09"; Oct = "10"; Nov = "11"; Dec = "12"
}

Get-ChildItem -Path $folder -Filter *.pdf | ForEach-Object {
    $name = $_.BaseName

    if ($name -match "Statement_([A-Za-z]{3})\s(\d{4})") {
        $monthAbbrev = $matches[1]
        $monthNum = $monthMap[$monthAbbrev]

        if ($monthNum) {
            $newName = "S$monthNum" + "_" + $_.Name
            Rename-Item $_.FullName -NewName $newName
            Write-Host "Renamed: $($_.Name) → $newName"
        }
    }
}
