$CI_COMMIT_SHA = $args[0]
$CI_MERGE_REQUEST_ID = $args[1]
$CI_MERGE_REQUEST_TARGET_BRANCH_NAME = $args[2]
$TOKEN = $args[3]
$REPOSITORY_URL = # Example: "https://gitlab.com/api/.../merge_requests"

$DefaultSizes = @{
    "XXL" = 2000
    "XL" = 800
    "L" = 200
    "M" = 50
    "S" = 20
    "XS" = 0
}

$DefaultSizeLabel = @{
    "XXL" = "Size: XXL"
    "XL" = "Size: XL"
    "L" = "Size: L"
    "M" = "Size: M"
    "S" = "Size: S"
    "XS" = "Size: XS"
}

function GetNumberOfChanges {
    Process {
        return((GetChangesFromGitRaw | ParseGitDiffChanges | Measure-Object -Sum).Sum)
    }
}

function GetChangesFromGitRaw{
    Process {
        return(git diff-tree --no-commit-id --numstat -r "$CI_COMMIT_SHA" "origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME")
    }
}

function ParseGitDiffChanges() {
[CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [string]$rawGitDifference
    )
    Process{
        return($rawGitDifference.Split("`n") | ForEach-Object {$_.Split("`t")} | Where-Object{$_ -match '^\d+$'})
    }
}

function GetSizeFromChanges(){
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [int]
        $NumberOfChanges,
        [Hashtable]
        $SizeNumOfChangesDictionary
    )
    Process{
        return(($SizeNumOfChangesDictionary.GetEnumerator()| Where-Object {$NumberOfChanges  -ge $_.Value} |Sort-Object -Property Value -Descending |Select-Object -First 1).Key)
    }
}

function GetLabelFromSize(){
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [String]
        $SizeNumOfChangesDictionary,
        [Hashtable]
        $SizeLabelDictionary
    )
    Process{
        return($SizeLabelDictionary[$SizeNumOfChangesDictionary])
    }
}

function SendLabelToMergeRequest(){
    param (
        [Parameter(ValueFromPipeline=$true)]
        [String]
        $LabelName,
        [String]
        $RepoURL,
        [String]
        $MergeRequestId,
        [String]
        $UserToken
    )
    Process{
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Bearer $UserToken")
        $headers.Add("Content-Type", "application/x-www-form-urlencoded")

        $body = "add_labels=$([System.Uri]::EscapeDataString($LabelName))"

        $response = Invoke-RestMethod "$RepoURL/$MergeRequestId" -Method 'PUT' -Headers $headers -Body $body
        $response | ConvertTo-Json
    }
}

GetNumberOfChanges | 
GetSizeFromChanges -SizeNumOfChangesDictionary $DefaultSizes| 
GetLabelFromSize -SizeLabelDictionary $DefaultSizeLabel |
SendLabelToMergeRequest -RepoURL "$REPOSITORY_URL" -MergeRequestId "$CI_MERGE_REQUEST_ID" -UserToken "$TOKEN"