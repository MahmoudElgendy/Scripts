# 1- Hellow world
function Get-HelloWorld {
    return "Hello, World!"
}

#2- Bob
function  Get-BobResponse{
    [cmdletBinding()]
    param(
        [string] $bobInput
    )
    $text = $bobInput.trim()
    if ($text -eq "") {
        return "Fine. Be that way!"
    }
    elseif ($text.EndsWith("?") -and (Is-Yelling $text)) {
        return "Calm down, I know what I'm doing!"
    }
    elseif ($text.EndsWith("?")) {
        return "Sure."
    }
    elseif (Is-Yelling $text) {
        return "Whoa, chill out!"
    }
    else {
        return "Whatever."
    }

}
function Is-Yelling{
    param([string] $input)
    $letters = $input -replace '[^a-zA-Z]', ''
    return ($letters -ne "" )-and( $letters -ceq $letters.ToUpper())
}
