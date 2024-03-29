﻿$forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
$entrycache = @{}

#
# Given a simple username (e.g. aoakley) find the AD entry
#
function Get-ADUser 
{  
    param($user=$(throw "Username required"))   

    if ($user -eq $null -or $user -eq "") { return $null }
        
    $domains = $()
    if ($user.Contains("\")) 
    {            
        ($domain, $user) = $user.split("\")
        $domains += $domain
    }
    else
    {
       foreach ($forestDomain in $forest.Domains)
       {
            $domains += $forestDomain.GetDirectoryEntry().distinguishedName
       }
    }
        
    foreach ($domainDN in $domains)
    {    
        $searcher = new-object DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domainDN")  
  
        $searcher.filter = "(&(objectClass=user)(sAMAccountName=$user))"  
        $Searcher.CacheResults = $true  
        $Searcher.SearchScope = "Subtree"
        $Searcher.PageSize = 10  
        
        $results = $searcher.findall()  
        
        if ($results -ne $null) { return $results[0] }
     }
} 

 

#
# Given a simple username (e.g. aoakley) iterate up through the hierarchy to the root
# adding each link to the entrycache hashtable
#
function Get-ADHierarchyUpwards
{
    param($user=$(throw "Username required"))   
    
    $u = get-ADuser $user
    $startUser = $lastUser = $user
        
    # slow cycle
    # populate the entrycache to the top
    while ($u.properties.manager.Count -ge 0)
    {
        if ($entrycache.ContainsKey($lastuser))
        {
	    # we already know the rest of the lineage
            break
        }

        $u = new-object DirectoryServices.DirectoryEntry "LDAP://$($u.properties.manager[0])"
        $manager = $u.properties.samaccountname.ToString().Trim() 
        $entrycache[$lastuser] = $manager
        $lastuser = $manager
    }
    
    # fast cycle
    # walk the entrycache to generate results
    $results = @()
    $u = $startUser
    while ($entrycache.ContainsKey($u))
    {
        $results += $u
        $u = $entrycache[$u]
    }
    $results += $u
    
    $results
}


#
# Given a simple username (e.g. aoakley) iterate down the hierarchy to the leaves
# adding each link to the entrycache hashtable
#
function Get-ADHierarchyDownwardsDE
{
	param($u, [array]$lineage)

	foreach ($report in $u.properties.directreports)
	{
        $u = new-object DirectoryServices.DirectoryEntry "LDAP://$report"

        $reportUsername = $u.properties.samaccountname.ToString().Trim() 
		$entrycache[$reportUsername] = $user
        @(, $($lineage + @($reportUsername)))  # magic!  prevents the array from being unwrapped in the pipeline
		if ($u.properties.directreports -ne $null)
		{
			Get-ADHierarchyDownwardsDE $u $($lineage + $($reportUsername))
		}
	}
}

function Get-ADHierarchyDownwards
{
    param($user=$(throw "Username required"))   
    
    $u = get-aduser $user   
    get-ADHierarchyDownwardsDE $u @($u.properties.samaccountname[0].ToString().Trim())
}




#
# Module stuff
#
Export-ModuleMember -function Get-ADUser, Get-ADHierarchyUpwards, Get-ADHierarchyDownwards
