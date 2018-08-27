
$baseURL = "https://www.hl.co.uk/funds/fund-discounts,-prices--and--factsheets/search-results"

$funds = @()
foreach ($l in [char[]](97..122) + '0') {
	$html = $(Invoke-WebRequest -uri "$baseURL/$l").RawContent
	if ($html.IndexOf("no funds starting with") -lt 0) {
		$x1 = $html.IndexOf('<ul class="list-unstyled list-indent"')
		$x1 = $html.IndexOf('>', $x1) + 1
		$x2 = $html.IndexOf('</ul>', $x1)
		$tbl = $html.substring($x1, $x2 - $x1).trim()

		for ($x1 = $tbl.IndexOf("href="); $x1 -ge 0; $x1 = $tbl.IndexOf("href=", $x2)) {
			$x1 = $tbl.IndexOf('"', $x1) + 1
			$x2 = $tbl.IndexOf('"', $x1)
			$funds += $tbl.Substring($x1, $x2 - $x1)
		}

	}
}

$funds | Export-Csv -Append funds.csv

$holdings = @()
for ($f = 1388; $f -lt $funds.count; $f++) {
	$html = $(Invoke-WebRequest -uri $funds[$f]).RawContent
	if ($html.IndexOf("Factsheet unavailable") -ge 0 -or
	    $html.IndexOf("Market data not available") -ge 0 -or
	    $html.IndexOf("holdings currently unavailable") -ge 0) {
		Write-Host -ForegroundColor Red $f $funds[$f].substring($baseURL.length) "- unavailable"
		continue
	}

	$x1 = $html.IndexOf('Fund size')
	$x1 = $html.IndexOf('<td', $x1)
	$x1 = $html.IndexOf(">", $x1) + 1
	$x2 = $html.IndexOf('</td', $x1)
	$fundSize = $html.Substring($x1, $x2 - $x1).trim()
	$fundSize = $fundSize -replace "&pound;", "GBP "
	$fundSize = $fundSize -replace "&euro;", "EUR "
	$fundSize = $fundSize -replace "&yen;", "YEN "
	$fundSize = $fundSize -replace "\$", "USD "

	$x1 = $html.IndexOf('<table class="factsheet-table" summary="Top 10 holdings"')
	$x1 = $html.IndexOf('>', $x1) + 1
	$x2 = $html.IndexOf('</table>', $x1)
	$tbl = $html.substring($x1, $x2 - $x1).trim()

	$headings = @()
	for ($x1 = $tbl.IndexOf('<th', 1); $x1 -gt 0; $x1 = $tbl.IndexOf('<th', $x2)) {
		$x1 = $tbl.IndexOf(">", $x1) + 1
		$x2 = $tbl.IndexOf("</th>", $x1)
		$headings += $tbl.Substring($x1, $x2 - $x1)
	}

	if ($headings.count -eq 0) {
		Write-Host -ForegroundColor Red $f $funds[$f].substring($baseURL.length) "- no table"
		continue
	}

	$i = 0
	for ($x1 = $tbl.IndexOf('<td', 0); $x1 -gt 0; $x1 = $tbl.IndexOf('<td', $x2)) {
		if ($i % $headings.count -eq 0) {
			$h = New-Object -TypeName PSObject -Property @{Fund=$funds[$f].substring($baseURL.length);Size=$fundSize}
		}
		$x1 = $tbl.IndexOf(">", $x1) + 1
		$x2 = $tbl.IndexOf("</td", $x1)
		$cell = $tbl.Substring($x1, $x2 - $x1).trim()
		if ($cell.Substring(0, 1) -eq '<') {
			$x1 = $tbl.IndexOf(">", $x1) + 1
			$x2 = $tbl.IndexOf("</a", $x1)
			$cell = $tbl.Substring($x1, $x2 - $x1).trim()
		}
		Add-Member -InputObject $h -MemberType NoteProperty -Name $headings[$i % $headings.count] -Value $cell
		$i++
		if ($i % $headings.count -eq 0) {
			$holdings += $h
		}
	}
	Write-Host $f $funds[$f].substring($baseURL.length) $fundSize ($i / 2) "holdings"
}

$holdings | Export-Csv holdings.csv


