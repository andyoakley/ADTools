﻿function Generate-Orgchart
{
    param($users)
    
@"
<html>
  <head>
    <script type='text/javascript' src='https://www.google.com/jsapi'></script>
    <script type='text/javascript'>
      google.load('visualization', '1', {packages:['orgchart']});
      google.setOnLoadCallback(drawChart);
      function drawChart() {
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'Name');
        data.addColumn('string', 'Manager');
        data.addColumn('string', 'ToolTip');
        data.addRows([
"@

    # used for lookups
    $hash = @{}
    $users | %{$hash[$_] = $_}

    # this is where the output will go
    $datalines = @()

    foreach ($user in $users)
    {
        $h = get-ADHierarchyUpwards $user
        foreach ($i in 0..(($h.Length)-2)) 
        { 
            $currentUser = $h[$i]
            $currentBoss = $h[$i+1]
            if ($hash.ContainsKey($currentUser)) { $meta = "<div style=`"color:green`">In list</div>" } else { $meta = "" }
            $datalines += "[{v:'$currentUser',f:'$currentUser $meta'}, '$currentBoss', '']" 
        }
    }

    # dedupe datalines (common managers will appear multiple times) and emit 
    [string]::Join(",`n", $($datalines | sort | get-unique))

@"
        ]);
        var chart = new google.visualization.OrgChart(document.getElementById('chart_div'));
        chart.draw(data, {allowHtml:true});
      }
    </script>
  </head>

  <body>
    <div id='chart_div'></div>
  </body>
</html>
"@

}




#
# Example upwards
# 
$usersRaw = @"
andy
bob
charles
"@

$users = @()
foreach ($line in $usersRaw.Split("`n"))
{
    $users += $line.Trim()
}    


$fn = [system.io.path]::gettempfilename() + ".htm"
generate-orgchart $users > $fn
ii $fn